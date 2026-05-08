import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Vyla Admin — DemyCorp Ltd",
  description: "Internal admin panel for Vyla Health",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-[#FFF6F0] antialiased">{children}</body>
    </html>
  );
}
