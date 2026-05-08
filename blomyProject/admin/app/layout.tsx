import type { Metadata } from "next";
import "./globals.css";
import Sidebar from "@/components/Sidebar";

export const metadata: Metadata = {
  title: "Vyla Admin — DemyCorp Ltd",
  description: "Internal admin panel for Vyla Health",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="bg-[#FFF6F0] antialiased">
        <div className="flex min-h-screen">
          <Sidebar />
          <main className="flex-1 px-8 py-8 overflow-auto">{children}</main>
        </div>
      </body>
    </html>
  );
}
