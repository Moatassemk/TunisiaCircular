export const sanitizeString = (str) => {
  if (typeof str !== 'string') return '';
  return str.trim().replace(/['";\-\-]/g, '');
};

export const validateEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

const governorates = [
  'Ariana', 'Beja', 'Ben Arous', 'Bizerte', 'Gabes', 'Gafsa', 'Jendouba',
  'Kairouan', 'Kasserine', 'Kebili', 'Kef', 'Mahdia', 'Manouba', 'Medenine',
  'Monastir', 'Nabeul', 'Sfax', 'Sidi Bouzid', 'Siliana', 'Sousse',
  'Tataouine', 'Tozeur', 'Tunis', 'Zaghouan'
];

export const validateGovernorate = (gov) => {
  return governorates.includes(gov);
};

export const validatePassword = (password) => {
  return typeof password === 'string' && password.length >= 8;
};
