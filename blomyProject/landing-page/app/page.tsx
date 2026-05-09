import type { Metadata } from "next";
import Nav from "@/components/Nav";
import HeroSection from "@/components/HeroSection";
import PressBar from "@/components/PressBar";
import WhyVylaSection from "@/components/WhyVylaSection";
import FeaturesSection from "@/components/FeaturesSection";
import AiSection from "@/components/AiSection";
import HowItWorksSection from "@/components/HowItWorksSection";
import PrivacySection from "@/components/PrivacySection";
import TestimonialsSection from "@/components/TestimonialsSection";
import PricingSection from "@/components/PricingSection";
import FAQSection from "@/components/FAQSection";
import CTASection from "@/components/CTASection";
import Footer from "@/components/Footer";

export const metadata: Metadata = {
  alternates: {
    canonical: "https://vyla.health",
  },
};

export default function Home() {
  return (
    <>
      <Nav />
      <main id="main-content">
        <HeroSection />
        <PressBar />
        <WhyVylaSection />
        <FeaturesSection />
        <AiSection />
        <HowItWorksSection />
        <PrivacySection />
        <TestimonialsSection />
        <PricingSection />
        <FAQSection />
        <CTASection />
      </main>
      <Footer />
    </>
  );
}
