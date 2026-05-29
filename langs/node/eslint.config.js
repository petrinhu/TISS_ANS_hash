// Flat config (ESLint 9+/10). Gate de lint mínimo e sensato pro port Node.
//
// Filosofia: a lib é pequena, sem framework, alvo Node >=20. Regras focam em
// pegar bug real (no-unused-vars, no-undef, eqeqeq, no-var) sem virar
// formatador estilístico — formatação fica fora do gate de CI pra não
// vermelhar por gosto. `recommended` do core já cobre o essencial.

import js from '@eslint/js';
import globals from 'globals';

export default [
  // Ignora artefatos que não devem ser lintados.
  {
    ignores: ['node_modules/**', 'coverage/**'],
  },

  js.configs.recommended,

  // Fonte ESM (.js) — Node moderno.
  {
    files: ['src/**/*.js', 'test/**/*.js'],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: 'module',
      globals: {
        ...globals.node,
      },
    },
    rules: {
      eqeqeq: ['error', 'always'],
      'no-var': 'error',
      'prefer-const': 'error',
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    },
  },

  // Shim CommonJS (.cjs).
  {
    files: ['src/**/*.cjs', 'test/**/*.cjs'],
    languageOptions: {
      ecmaVersion: 2023,
      sourceType: 'commonjs',
      globals: {
        ...globals.node,
      },
    },
    rules: {
      eqeqeq: ['error', 'always'],
      'no-var': 'error',
      'prefer-const': 'error',
      'no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
    },
  },
];
