import type { NextConfig } from 'next';
import createNextIntlPlugin from 'next-intl/plugin';

const withNextIntl = createNextIntlPlugin();

const nextConfig: NextConfig = {
  // Required for the production Docker image (copies only the minimal runtime).
  output: 'standalone',
};

export default withNextIntl(nextConfig);
