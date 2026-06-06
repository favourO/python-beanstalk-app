import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: {
    unoptimized: true,
    remotePatterns: [
      { protocol: "https", hostname: "vyla.health" },
      { protocol: "https", hostname: "prod.vyla.health" },
      { protocol: "https", hostname: "prod.api.vyla.health" },
      { protocol: "https", hostname: "stage.vyla.health" },
      { protocol: "https", hostname: "stage.api.vyla.health" },
    ],
  },
};

export default nextConfig;
