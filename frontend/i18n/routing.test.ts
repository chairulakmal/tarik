import { describe, it, expect } from 'vitest';
import { routing } from '@/i18n/routing';

describe('routing', () => {
  it('supports English and Japanese', () => {
    expect(routing.locales).toContain('en');
    expect(routing.locales).toContain('ja');
  });

  it('defaults to English', () => {
    expect(routing.defaultLocale).toBe('en');
  });
});
