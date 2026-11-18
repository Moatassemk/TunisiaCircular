/**
 * Seed script for initial data
 * Run: node seeds/seed.js
 */

import pkg from 'pg';
const { Pool } = pkg;
import bcrypt from 'bcryptjs';
import dotenv from 'dotenv';

dotenv.config();

const pool = new Pool(process.env.DATABASE_URL
  ? { connectionString: process.env.DATABASE_URL }
  : {
      host: process.env.DB_HOST || 'localhost',
      port: Number(process.env.DB_PORT || 5432),
      database: process.env.DB_NAME || 'tunisia_circular',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres'
    });

const seedData = {
  users: [
    {
      email: 'admin@clac.tn',
      password: 'Admin123!',
      role: 'admin',
      name: 'Admin CLAC',
      company_name: 'CLAC SARL',
      gouvernorat: 'Tunis'
    },
    {
      email: 'sfax.olive@mills.tn',
      password: 'Farm123!',
      role: 'generator',
      name: 'Olive Mill Sfax Nord',
      company_name: 'Sfax Olive Mills Co.',
      gouvernorat: 'Sfax',
      phone: '+216 97 123 456'
    },
    {
      email: 'restaurant.med@tn',
      password: 'Rest123!',
      role: 'generator',
      name: 'Restaurant Le Méditerranée',
      company_name: 'Le Méditerranée SARL',
      gouvernorat: 'Tunis',
      phone: '+216 71 234 567'
    },
    {
      email: 'biofuel@tunisie.com',
      password: 'Fuel123!',
      role: 'processor',
      name: 'BioFuel Tunisia',
      company_name: 'BioFuel Tunisia SA',
      gouvernorat: 'Ariana',
      phone: '+216 71 000 111'
    },
    {
      email: 'olive.extract@sfax.tn',
      password: 'Extract123!',
      role: 'processor',
      name: 'OliveExtract Sfax',
      company_name: 'OliveExtract SNC',
      gouvernorat: 'Sfax',
      phone: '+216 97 000 222'
    },
    {
      email: 'driver@test.tn',
      password: 'Driver123!',
      role: 'collector',
      name: 'Mohamed Transport',
      company_name: 'Mohamed Logistics',
      gouvernorat: 'Tunis',
      phone: '+216 50 123 456'
    },
    {
      email: 'green.collect@tn',
      password: 'Green123!',
      role: 'collector',
      name: 'GreenMinds Collect',
      company_name: 'GreenMinds Collecting Society',
      gouvernorat: 'Tunis',
      phone: '+216 71 777 888'
    },
    {
      email: 'marche.gros@bir.kassaa.tn',
      password: 'Market123!',
      role: 'generator',
      name: 'Marché de Gros Bir El Kassaa',
      company_name: 'Marché de Gros Bir El Kassaa',
      gouvernorat: 'Tunis',
      phone: '+216 71 345 678'
    },
    {
      email: 'huilerie.medenine@tunisie.com',
      password: 'Mill123!',
      role: 'generator',
      name: 'Huilerie Médenine Centro',
      company_name: 'Huilerie Médenine Centro',
      gouvernorat: 'Medenine',
      phone: '+216 75 456 789'
    },
    {
      email: 'djerba.beach@tn',
      password: 'Resort123!',
      role: 'generator',
      name: 'Hôtel Djerba Beach',
      company_name: 'Hôtel Djerba Beach',
      gouvernorat: 'Medenine',
      phone: '+216 75 567 890'
    },
    {
      email: 'citrus.grombalia@tn',
      password: 'Citrus123!',
      role: 'generator',
      name: 'Citrus Processing Unit Grombalia',
      company_name: 'Citrus Processing Unit Grombalia',
      gouvernorat: 'Ariana',
      phone: '+216 71 678 901'
    },
    {
      email: 'compost@tn',
      password: 'Compost123!',
      role: 'processor',
      name: 'Compost Plus Tunisie',
      company_name: 'Compost Plus Tunisie',
      gouvernorat: 'Tunis',
      phone: '+216 71 555 000'
    },
    {
      email: 'greenbrick@tn',
      password: 'Brick123!',
      role: 'processor',
      name: 'GreenBrick Manufacturing',
      company_name: 'GreenBrick Manufacturing',
      gouvernorat: 'Mahdia',
      phone: '+216 53 555 000'
    },
    {
      email: 'biogas.medenine@tn',
      password: 'Biogas123!',
      role: 'processor',
      name: 'Biogas Médenine',
      company_name: 'Biogas Médenine',
      gouvernorat: 'Medenine',
      phone: '+216 75 555 000'
    },
    {
      email: 'saouera.soap@tn',
      password: 'Soap123!',
      role: 'processor',
      name: 'Saouera Eco-Savon',
      company_name: 'Saouera Eco-Savon',
      gouvernorat: 'Sidi Bouzid',
      phone: '+216 52 555 000'
    }
  ],
  generators: [
    {
      name: 'Olive Mill Sfax Nord',
      owner_email: 'sfax.olive@mills.tn',
      type: 'olive_mill',
      description: 'Major olive oil mill serving northern Sfax region',
      lat: 34.7500,
      lng: 10.7612,
      available_waste_types: ['pomace'],
      avg_monthly_volume_kg: 5000,
      seasonal: true,
      contact_phone: '+216 97 123 456',
      contact_email: 'contact@sfaxnord.tn',
      gouvernorat: 'Sfax'
    },
    {
      name: 'Restaurant Le Méditerranée',
      owner_email: 'restaurant.med@tn',
      type: 'restaurant',
      description: 'Hotel restaurant serving 200+ meals daily',
      lat: 36.8065,
      lng: 10.1815,
      available_waste_types: ['usedCookingOil'],
      avg_monthly_volume_kg: 50,
      seasonal: false,
      contact_phone: '+216 71 234 567',
      contact_email: 'info@lemediterranee.tn',
      gouvernorat: 'Tunis'
    },
    {
      name: 'Marché de Gros Bir El Kassaa',
      owner_email: 'marche.gros@bir.kassaa.tn',
      type: 'wholesale_market',
      description: 'Main wholesale food market in Greater Tunis',
      lat: 36.8530,
      lng: 10.2360,
      available_waste_types: ['organicFood'],
      avg_monthly_volume_kg: 5000,
      seasonal: false,
      contact_phone: '+216 71 345 678',
      contact_email: 'direction@bir.kassaa.tn',
      gouvernorat: 'Tunis'
    },
    {
      name: 'Huilerie Médenine Centro',
      owner_email: 'huilerie.medenine@tunisie.com',
      type: 'olive_mill',
      description: 'Modern olive mill in the heart of Medenine governorate',
      lat: 33.5140,
      lng: 9.9520,
      available_waste_types: ['pomace'],
      avg_monthly_volume_kg: 3000,
      seasonal: true,
      contact_phone: '+216 75 456 789',
      contact_email: 'huilerie.medenine@tunisie.com',
      gouvernorat: 'Medenine'
    },
    {
      name: 'Hôtel Djerba Beach',
      owner_email: 'djerba.beach@tn',
      type: 'hotel',
      description: 'Beach resort with restaurant and banquet facilities',
      lat: 33.8755,
      lng: 10.0850,
      available_waste_types: ['foodWaste', 'usedCookingOil'],
      avg_monthly_volume_kg: 200,
      seasonal: false,
      contact_phone: '+216 75 567 890',
      contact_email: 'direction@djerbabeach.tn',
      gouvernorat: 'Medenine'
    },
    {
      name: 'Citrus Processing Unit Grombalia',
      owner_email: 'citrus.grombalia@tn',
      type: 'fruit_veg_processor',
      description: 'Processes oranges, clementines, and lemons for export',
      lat: 36.5500,
      lng: 10.4000,
      available_waste_types: ['organicFood', 'pomace'],
      avg_monthly_volume_kg: 2000,
      seasonal: true,
      contact_phone: '+216 71 678 901',
      contact_email: 'info@grombalia-citrus.tn',
      gouvernorat: 'Ariana'
    }
  ],
  processors: [
    {
      name: 'BioFuel Tunisia (Biodiesel)',
      owner_email: 'biofuel@tunisie.com',
      type: 'biodiesel_refinery',
      description: 'Converts used cooking oil into biodiesel for industrial and automotive use',
      lat: 35.7640,
      lng: 9.1810,
      accepts_waste_types: ['usedCookingOil'],
      max_capacity_kg_per_month: 50000,
      current_stock_kg: 12000,
      price_per_kg: 0,
      price_per_liter: 1.80,
      payment_terms: 'Net 30 days after delivery',
      gouvernorat: 'Bizerte'
    },
    {
      name: 'OliveExtract Sfax',
      owner_email: 'olive.extract@sfax.tn',
      type: 'polyphenol_extractor',
      description: 'Extracts polyphenols and antioxidants from olive pomace for cosmetic and pharmaceutical industries',
      lat: 34.7400,
      lng: 10.7600,
      accepts_waste_types: ['pomace'],
      max_capacity_kg_per_month: 500000,
      current_stock_kg: 80000,
      price_per_kg: 25,
      payment_terms: 'Net 45 days',
      gouvernorat: 'Sfax'
    },
    {
      name: 'Compost Plus Tunisie',
      type: 'composting_plant',
      description: 'Industrial composting facility producing organic fertilizer for agriculture',
      lat: 36.8200,
      lng: 10.1700,
      accepts_waste_types: ['organicFood', 'pomace'],
      max_capacity_kg_per_month: 1000000,
      current_stock_kg: 200000,
      price_per_kg: 15,
      payment_terms: 'Net 30 days',
      gouvernorat: 'Tunis'
    },
    {
      name: 'GreenBrick Manufacturing',
      type: 'biomass_fired_kiln',
      description: 'Uses olive stones as biomass fuel for brick manufacturing',
      lat: 34.5000,
      lng: 10.5000,
      accepts_waste_types: ['pomace_stones'],
      max_capacity_kg_per_month: 2000000,
      current_stock_kg: 500000,
      price_per_kg: 10,
      payment_terms: 'Cash on delivery',
      gouvernorat: 'Mahdia'
    },
    {
      name: 'Biogas Médenine',
      type: 'anaerobic_digester',
      description: 'Anaerobic digestion facility converting organic waste to biogas and digestate',
      lat: 33.5100,
      lng: 9.9500,
      accepts_waste_types: ['organicFood', 'pomace', 'foodWaste'],
      max_capacity_kg_per_month: 800000,
      current_stock_kg: 150000,
      price_per_kg: 12,
      payment_terms: 'Net 60 days',
      gouvernorat: 'Medenine'
    },
    {
      name: 'Saouera Eco-Savon',
      type: 'soap_manufacturer',
      description: 'Produces eco-friendly soap from used cooking oil and olive by-products',
      lat: 35.5000,
      lng: 8.9500,
      accepts_waste_types: ['usedCookingOil', 'pomace'],
      max_capacity_kg_per_month: 100000,
      current_stock_kg: 30000,
      price_per_kg: 0,
      price_per_liter: 2.00,
      payment_terms: 'Net 30 days',
      gouvernorat: 'Sidi Bouzid'
    }
  ],
  collectionPoints: [
    {
      owner_email: 'green.collect@tn',
      name: 'GreenMinds Tunis Drop-off',
      point_type: 'drop_off',
      description: 'Neighbourhood drop-off run by the GreenMinds collecting society.',
      address: 'Rue de Marseille, Tunis Centre',
      gouvernorat: 'Tunis',
      lat: 36.8008,
      lng: 10.1800,
      accepts_waste_types: ['usedCookingOil', 'organicFood'],
      contact_phone: '+216 71 777 888',
      opening_hours: 'Mon–Sat 08:00–18:00',
      is_verified: true
    },
    {
      owner_email: 'sfax.olive@mills.tn',
      name: 'Sfax Olive Mills Bizerte Pickup',
      point_type: 'pickup_site',
      description: 'Bizerte pickup point operated by Sfax Olive Mills for northern suppliers.',
      address: 'Zone Industrielle, Bizerte',
      gouvernorat: 'Bizerte',
      lat: 37.2744,
      lng: 9.8739,
      accepts_waste_types: ['pomace'],
      contact_phone: '+216 97 123 456',
      opening_hours: 'Mon–Fri 07:00–17:00',
      is_verified: true
    },
    {
      owner_email: 'green.collect@tn',
      name: 'GreenMinds Sousse Collection Point',
      point_type: 'recycling_center',
      description: 'New coastal collection centre awaiting admin verification.',
      address: 'Avenue Habib Bourguiba, Sousse',
      gouvernorat: 'Sousse',
      lat: 35.8256,
      lng: 10.6370,
      accepts_waste_types: ['usedCookingOil'],
      contact_phone: '+216 71 777 888',
      opening_hours: 'Mon–Sat 09:00–17:00',
      is_verified: false
    }
  ]
};

async function seed() {
  try {
    // Seed users
    console.log('🌱 Seeding users...');
    for (const userData of seedData.users) {
      const hashedPassword = await bcrypt.hash(userData.password, 10);
      await pool.query(`
        INSERT INTO users (email, password_hash, role, name, company_name, gouvernorat, phone, is_active, is_verified)
        VALUES ($1, $2, $3, $4, $5, $6, $7, true, true)
        ON CONFLICT (email) DO NOTHING
      `, [userData.email, hashedPassword, userData.role, userData.name, userData.company_name, userData.gouvernorat, userData.phone]);
    }
    const demoEmails = seedData.users.map((userData) => userData.email);
    await pool.query('UPDATE users SET is_verified = true WHERE email = ANY($1::text[])', [demoEmails]);
    console.log('✅ Users seeded');

    // Seed waste generators
    console.log('🌿 Seeding waste generators...');
    for (const genData of seedData.generators) {
      const ownerResult = genData.owner_email
        ? await pool.query('SELECT id FROM users WHERE email = $1', [genData.owner_email])
        : null;
      const ownerId = ownerResult?.rows[0]?.id || null;
      await pool.query(`
        INSERT INTO waste_generators (user_id, name, type, description, lat, lng, available_waste_types,
          avg_monthly_volume_kg, seasonal, contact_phone, contact_email, gouvernorat, location)
        SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
          ST_SetSRID(ST_Point($6, $5), 4326)
        WHERE NOT EXISTS (SELECT 1 FROM waste_generators WHERE name = $2::varchar(255))
      `, [
        ownerId, genData.name, genData.type, genData.description,
        genData.lat, genData.lng, genData.available_waste_types,
        genData.avg_monthly_volume_kg, genData.seasonal,
        genData.contact_phone, genData.contact_email, genData.gouvernorat
      ]);
      if (ownerId) {
        await pool.query(
          'UPDATE waste_generators SET user_id = $1 WHERE name = $2 AND user_id IS DISTINCT FROM $1',
          [ownerId, genData.name]
        );
      }
    }
    console.log('✅ Waste generators seeded');

    // Seed processors
    console.log('⚙️ Seeding processors...');
    for (const procData of seedData.processors) {
      const ownerResult = procData.owner_email
        ? await pool.query('SELECT id FROM users WHERE email = $1', [procData.owner_email])
        : null;
      const ownerId = ownerResult?.rows[0]?.id || null;
      await pool.query(`
        INSERT INTO processors (user_id, name, type, description, lat, lng, accepts_waste_types,
          max_capacity_kg_per_month, current_stock_kg, price_per_kg, price_per_liter,
          payment_terms, gouvernorat, location)
        SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13,
          ST_SetSRID(ST_Point($6, $5), 4326)
        WHERE NOT EXISTS (SELECT 1 FROM processors WHERE name = $2::varchar(255))
      `, [
        ownerId, procData.name, procData.type, procData.description,
        procData.lat, procData.lng, procData.accepts_waste_types,
        procData.max_capacity_kg_per_month, procData.current_stock_kg,
        procData.price_per_kg, procData.price_per_liter,
        procData.payment_terms, procData.gouvernorat
      ]);
      if (ownerId) {
        await pool.query(
          'UPDATE processors SET user_id = $1 WHERE name = $2 AND user_id IS DISTINCT FROM $1',
          [ownerId, procData.name]
        );
      }
    }
    console.log('✅ Processors seeded');

    // Seed collection points owned by a collecting society and by a seller
    // operating outside its home governorate.
    console.log('📍 Seeding collection points...');
    for (const pointData of seedData.collectionPoints) {
      const ownerResult = await pool.query('SELECT id FROM users WHERE email = $1', [pointData.owner_email]);
      const ownerId = ownerResult.rows[0]?.id;
      if (!ownerId) continue;
      await pool.query(`
        INSERT INTO collection_points (owner_id, name, point_type, description, address,
          gouvernorat, lat, lng, location, accepts_waste_types, contact_phone,
          opening_hours, is_active, is_verified)
        SELECT $1, $2, $3, $4, $5, $6, $7, $8,
          ST_SetSRID(ST_Point($8, $7), 4326), $9, $10, $11, true, $12
        WHERE NOT EXISTS (SELECT 1 FROM collection_points WHERE name = $2::varchar(255))
      `, [
        ownerId, pointData.name, pointData.point_type, pointData.description,
        pointData.address, pointData.gouvernorat, pointData.lat, pointData.lng,
        pointData.accepts_waste_types, pointData.contact_phone,
        pointData.opening_hours, pointData.is_verified,
      ]);
    }
    console.log('✅ Collection points seeded');

    console.log('\n🎉 Database seeded successfully!');

    // Print admin credentials
    console.log('\n📋 Admin Credentials:');
    console.log('   Email: admin@clac.tn');
    console.log('   Password: Admin123!');

    await pool.end();
  } catch (error) {
    console.error('❌ Error seeding database:', error.message);
    process.exit(1);
  }
}

seed();
