/**
 * Matching service - AI-powered waste-to-processor matching
 */
import { query } from '../db.js';

/**
 * Haversine formula to calculate distance between two points on earth
 */
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

/**
 * Get carbon factor for a specific waste type and processor type combination
 */
async function getCarbonFactor(wasteType, processorType) {
  const mappings = {
    'pomace': {
      'polyphenol_extractor': 'polyphenol_extraction',
      'composting_plant': 'compost_pomace',
      'anaerobic_digester': 'biogas_pomace',
      'biomass_fired_kiln': 'biomass_fuel'
    },
    'pomace_stones': {
      'polyphenol_extractor': 'polyphenol_extraction',
      'composting_plant': 'compost_pomace',
      'anaerobic_digester': 'biogas_pomace',
      'biomass_fired_kiln': 'biomass_fuel'
    },
    'usedCookingOil': {
      'biodiesel_refinery': 'biodiesel_from_uco',
      'soap_manufacturer': 'biodiesel_from_uco'
    },
    'organicFood': {
      'composting_plant': 'compost_organic',
      'anaerobic_digester': 'biogas_organic'
    },
    'foodWaste': {
      'composting_plant': 'compost_organic',
      'anaerobic_digester': 'biogas_organic'
    }
  };

  // Try direct mapping first, then fall back gracefully
  let factorKey = mappings[wasteType]?.[processorType] || null;
  if (!factorKey) {
    // Default fallback based on waste type if processor type not found
    const defaults = {
      'pomace': 'compost_pomace',
      'pomace_stones': 'compost_pomace',
      'usedCookingOil': 'biodiesel_from_uco',
      'organicFood': 'compost_organic',
      'foodWaste': 'compost_organic'
    };
    factorKey = defaults[wasteType] || 'landfill_organic';
  }
  const result = await query('SELECT * FROM carbon_factors WHERE factor_key = $1', [factorKey]);
  return result.rows[0];
}

/**
 * Calculate capacity score (0-1)
 */
function capacityScore(generatorVolume, processorCapacity) {
  if (!generatorVolume || !processorCapacity) return 0.5;
  return Math.min(generatorVolume / processorCapacity, 1);
}

/**
 * Calculate match score between generator and processor
 */
async function calculateMatchScore(generator, processor, amountKg) {
  const distance = haversineDistance(
    generator.lat, generator.lng,
    processor.lat, processor.lng
  );

  // Capacity fit (60% weight)
  const capFit = capacityScore(
    amountKg || generator.avg_monthly_volume_kg,
    processor.max_capacity_kg_per_month
  );

  // Distance score (30% weight) - closer is better
  const distanceScore = 1 / (1 + distance / 50); // Normalize: at 50km = 0.5 score

  // Price competitiveness (10% weight)
  const pricePerTon = processor.price_per_liter
    ? processor.price_per_liter * 1000
    : (processor.price_per_kg || 0);
  const priceScore = Math.min(pricePerTon / 30, 1); // Average market rate ~30 TND/ton

  const totalScore = (capFit * 0.6) + (distanceScore * 0.3) + (priceScore * 0.1);

  return {
    processor,
    distanceKm: Number(distance.toFixed(1)),
    score: Number(totalScore.toFixed(3)),
    capFit: Number(capFit.toFixed(3)),
    distanceScore: Number(distanceScore.toFixed(3)),
    priceScore: Number(priceScore.toFixed(3))
  };
}

/**
 * Estimate carbon impact of a transaction
 */
async function estimateImpact(transaction) {
  const { wasteType, processorType, amountKg, amountLiter, distanceKm } = transaction;
  const factor = await getCarbonFactor(wasteType, processorType);

  if (!factor) {
    return { kgCO2eSaved: 0, breakdown: {} };
  }

  const transportEmission = parseFloat(factor.kg_co2e_per_km || 0.62);
  const transportCost = distanceKm * transportEmission * Math.min(amountKg / 5000, 1);

  let avoidedLandfill = 0;
  let processingSavings = 0;

  if (factor.kg_co2e_per_kg) {
    avoidedLandfill = amountKg * parseFloat(factor.kg_co2e_per_kg);
  }
  if (factor.kg_co2e_saved_per_kg) {
    processingSavings = amountKg * parseFloat(factor.kg_co2e_saved_per_kg);
  }
  // Liquid waste factors (e.g. used cooking oil → biodiesel) are stored per liter.
  if (factor.kg_co2e_saved_per_liter) {
    processingSavings += (amountLiter || 0) * parseFloat(factor.kg_co2e_saved_per_liter);
  }

  const totalSaved = avoidedLandfill + processingSavings - transportCost;

  return {
    kgCO2eSaved: Number(totalSaved.toFixed(2)),
    breakdown: {
      avoided_landfill: Number(avoidedLandfill.toFixed(2)),
      processing_savings: Number(processingSavings.toFixed(2)),
      transport_emissions: Number(-transportCost.toFixed(2))
    }
  };
}

/**
 * Find best matches for a generator
 */
export async function findMatches(generatorId, amountKg) {
  try {
    // Get generator details
    const genResult = await query(
      `SELECT g.* FROM waste_generators g
       JOIN users u ON u.id = g.user_id
       WHERE g.id = $1 AND u.is_active = true AND u.is_verified = true`,
      [generatorId]
    );

    if (genResult.rows.length === 0) {
      throw new Error('Generator not found');
    }

    const generator = genResult.rows[0];
    const wasteTypes = Array.isArray(generator.available_waste_types)
      ? generator.available_waste_types
      : JSON.parse(generator.available_waste_types);

    // Get compatible processors
    const procResult = await query(`
      SELECT p.* FROM processors p
      JOIN users u ON u.id = p.user_id
      WHERE EXISTS (
        SELECT 1 FROM unnest(p.accepts_waste_types) AS t
        WHERE t = ANY($1::varchar[])
      ) AND p.is_active = true AND u.is_active = true AND u.is_verified = true
    `, [wasteTypes]);

    if (procResult.rows.length === 0) {
      return { generator, matches: [], message: 'No compatible processors found' };
    }

    // Calculate scores for each processor
    const matches = await Promise.all(
      procResult.rows.map(async (processor) => {
        const { processor: proc, distanceKm, score, capFit, distanceScore, priceScore } =
          await calculateMatchScore(generator, processor, amountKg);

        // Estimate carbon impact
        const impact = await estimateImpact({
          wasteType: wasteTypes[0],
          processorType: proc.type,
          amountKg: amountKg || generator.avg_monthly_volume_kg,
          distanceKm
        });

        return {
          ...proc,
          distanceKm,
          score,
          capFit,
          distanceScore,
          priceScore,
          estimatedImpact: impact
        };
      })
    );

    // Sort by score (descending)
    matches.sort((a, b) => b.score - a.score);

    // Save matches to database for audit
    for (const match of matches.slice(0, 5)) {
      await query(`
        INSERT INTO matches (generator_id, processor_id, score, distance_km, selected)
        VALUES ($1, $2, $3, $4, false)
      `, [generatorId, match.id, match.score, match.distanceKm]);
    }

    return {
      generator: { ...generator, available_waste_types: wasteTypes },
      matches: matches.slice(0, 3) // Return top 3
    };
  } catch (error) {
    console.error('Error in findMatches:', error);
    throw error;
  }
}

/**
 * Get dashboard statistics
 */
export async function getDashboardStats() {
  try {
    const [statsResult, recentTx, wasteByType, topActors] = await Promise.all([
      query(`
        SELECT
          (SELECT COUNT(*) FROM waste_generators) AS generators,
          (SELECT COUNT(*) FROM processors WHERE is_active = true) AS processors,
          (SELECT COUNT(*) FROM transactions) AS transactions,
          (SELECT COALESCE(SUM(amount_kg), 0) FROM transactions WHERE status = 'completed') AS total_waste_diverted_kg,
          (SELECT COALESCE(SUM(total_carbon_saved_kg), 0) FROM transactions WHERE status = 'completed') AS total_carbon_saved_kg_co2e,
          (SELECT COALESCE(AVG(distance_km), 0) FROM transactions WHERE status = 'completed') AS average_distance_km,
          (SELECT COALESCE(SUM(avg_monthly_volume_kg), 0) FROM waste_generators) AS monthly_potential_kg
      `),
      query(`
        SELECT t.*, wg.name as generator_name, p.name as processor_name
        FROM transactions t
        LEFT JOIN waste_generators wg ON wg.id = t.generator_id
        LEFT JOIN processors p ON p.id = t.processor_id
        ORDER BY t.created_at DESC
        LIMIT 10
      `),
      query(`
        SELECT waste_type, SUM(amount_kg) as total_kg
        FROM transactions
        GROUP BY waste_type
        ORDER BY total_kg DESC
        LIMIT 5
      `),
      query(`
        SELECT wg.name, SUM(t.amount_kg) as total_kg
        FROM waste_generators wg
        JOIN transactions t ON t.generator_id = wg.id
        GROUP BY wg.name
        ORDER BY total_kg DESC
        LIMIT 5
      `)
    ]);

    const stats = statsResult.rows[0];

    return {
      generators: stats.generators,
      processors: stats.processors,
      transactions: stats.transactions,
      totalWasteDivertedKg: Number(stats.total_waste_diverted_kg),
      totalCarbonSavedKgCO2e: Number(stats.total_carbon_saved_kg_co2e),
      averageDistanceKm: Number(Number(stats.average_distance_km).toFixed(1)),
      monthlyPotentialKg: Number(stats.monthly_potential_kg),
      recentTransactions: recentTx.rows,
      wasteByType: wasteByType.rows,
      topActors: topActors.rows
    };
  } catch (error) {
    console.error('Error getting dashboard stats:', error);
    throw error;
  }
}

/**
 * Get hourly carbon intensity forecast for Tunisia
 * Based on solar pattern (Tunisia grid has significant solar contribution)
 */
export function getCarbonIntensityForecast() {
  const hours = [];
  const baseIntensity = 420; // gCO2/kWh average for Tunisia grid

  for (let h = 0; h < 24; h++) {
    // Solar curve: peaks at noon (hour 12), zero at night
    const solarFactor = Math.max(0, Math.sin(((h - 6) * Math.PI) / 12));
    const intensity = Math.round(baseIntensity * (1 - solarFactor * 0.35));

    let rating;
    if (intensity < 280) rating = '🟢 Clean';
    else if (intensity < 350) rating = '🟡 Moderate';
    else rating = '🔴 Dirty';

    hours.push({
      hour: h,
      intensity_gCO2kWh: intensity,
      rating
    });
  }

  return hours;
}

/**
 * Create a transaction
 */
export async function createTransaction(data) {
  try {
    const {
      generatorId,
      processorId,
      amountKg,
      amountLiter,
      notes
    } = data;

    // Get generator info
    const genResult = await query('SELECT * FROM waste_generators WHERE id = $1', [generatorId]);
    if (!genResult.rows[0]) throw new Error('Generator not found');

    // Get processor info
    const procResult = await query('SELECT * FROM processors WHERE id = $1', [processorId]);
    if (!procResult.rows[0]) throw new Error('Processor not found');

    const generator = genResult.rows[0];
    const processor = procResult.rows[0];

    // Calculate distance
    const distance = haversineDistance(
      generator.lat, generator.lng,
      processor.lat, processor.lng
    );

    // Get waste types
    const wasteTypes = Array.isArray(generator.available_waste_types)
      ? generator.available_waste_types
      : JSON.parse(generator.available_waste_types);
    const acceptedTypes = Array.isArray(processor.accepts_waste_types)
      ? processor.accepts_waste_types
      : JSON.parse(processor.accepts_waste_types);
    const wasteType = wasteTypes.find((type) => acceptedTypes.includes(type));
    if (!wasteType) throw new Error('Buyer does not accept any material on this listing');

    // Calculate carbon impact
    const impact = await estimateImpact({
      wasteType,
      processorType: processor.type,
      amountKg: amountKg || generator.avg_monthly_volume_kg || 100,
      amountLiter: amountLiter,
      distanceKm: distance
    });

    // Create transaction
    const txResult = await query(`
      INSERT INTO transactions (
        generator_id, processor_id, waste_type, amount_kg, amount_liter,
        distance_km, transport_emissions_kg, avoided_landfill_kg,
        processing_savings_kg, total_carbon_saved_kg, status,
        match_score, notes, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 'pending', $11, $12, NOW())
      RETURNING *
    `, [
      generatorId, processorId, wasteType,
      amountKg || generator.avg_monthly_volume_kg || 100,
      amountLiter,
      parseFloat(distance.toFixed(1)),
      parseFloat(impact.breakdown.transport_emissions || 0),
      parseFloat(impact.breakdown.avoided_landfill || 0),
      parseFloat(impact.breakdown.processing_savings || 0),
      impact.kgCO2eSaved,
      null,
      notes || null
    ]);

    const transaction = txResult.rows[0];

    // Generate notification for processor
    await query(`
      INSERT INTO notifications (user_id, type, title, message, link, created_at)
      SELECT
        p.user_id,
        'new_transaction',
        'New Waste Match!',
        $1 || ' has a new waste offering ready for collection.',
        '/transactions/' || t.id,
        NOW()
      FROM transactions t
      CROSS JOIN processors p
      WHERE t.id = $2 AND p.id = $3
    `, [generator.name, transaction.id, processorId]);

    // Also notify generator
    await query(`
      INSERT INTO notifications (user_id, type, title, message, link, created_at)
      SELECT
        wg.user_id,
        'transaction_created',
        'Transaction Created',
        $1 || ' has been matched with ' || $2,
        '/transactions/' || t.id,
        NOW()
      FROM transactions t
      CROSS JOIN waste_generators wg
      WHERE t.id = $3 AND wg.id = $4
    `, [processor.name, generator.name, transaction.id, generatorId]);

    return transaction;
  } catch (error) {
    console.error('Error creating transaction:', error);
    throw error;
  }
}
