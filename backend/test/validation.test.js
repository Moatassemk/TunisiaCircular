import test from 'node:test';
import assert from 'node:assert/strict';
import {
  validateEmail,
  validateGovernorate,
  validatePassword,
} from '../src/utils/validation.js';

test('email validation rejects missing or malformed addresses', () => {
  assert.equal(validateEmail('ops@clac.tn'), true);
  assert.equal(validateEmail('not-an-email'), false);
  assert.equal(validateEmail(''), false);
});

test('governorate validation accepts the supported Tunisia list only', () => {
  assert.equal(validateGovernorate('Tunis'), true);
  assert.equal(validateGovernorate('Sidi Bouzid'), true);
  assert.equal(validateGovernorate('Paris'), false);
});

test('password validation enforces the minimum length', () => {
  assert.equal(validatePassword('secure123'), true);
  assert.equal(validatePassword('short'), false);
  assert.equal(validatePassword(''), false);
});
