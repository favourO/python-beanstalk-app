import Link from "next/link";
import Image from "next/image";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Terms of Use",
  description:
    "Read the terms that govern your access to and use of Vyla's cycle tracking app and services. Covers permitted use, subscriptions, and data rights.",
  alternates: { canonical: "https://vyla.health/terms" },
  robots: { index: true, follow: true },
};

function Section({ id, title, children }: { id: string; title: string; children: React.ReactNode }) {
  return (
    <section id={id} className="mb-12">
      <h2 className="font-serif text-2xl font-semibold text-[#1E0C16] mb-5 pb-3 border-b border-[#FFD9C2]">
        {title}
      </h2>
      <div className="space-y-4">{children}</div>
    </section>
  );
}

function P({ children }: { children: React.ReactNode }) {
  return <p className="text-[15px] font-light text-[#3D1F2E] leading-relaxed">{children}</p>;
}

function Ul({ items }: { items: React.ReactNode[] }) {
  return (
    <ul className="space-y-1.5 pl-1">
      {items.map((item, i) => (
        <li key={i} className="flex gap-2.5 text-[15px] font-light text-[#3D1F2E] leading-relaxed">
          <span className="text-[#FF7A33] mt-[3px] shrink-0">–</span>
          <span>{item}</span>
        </li>
      ))}
    </ul>
  );
}

export default function TermsPage() {
  return (
    <div className="min-h-screen bg-[#FFF6F0]">
      {/* Top bar */}
      <header className="bg-white border-b border-[#FFD9C2]">
        <div className="max-w-[1200px] mx-auto px-6 h-16 flex items-center justify-between">
          <Link href="/">
            <Image src="https://vyla.health/assets/vyla-logo.png" alt="Vyla" width={1536} height={1024} className="h-26 w-auto" unoptimized />
          </Link>
          <Link href="/" className="text-sm font-medium text-[#A06A52] hover:text-[#1E0C16] transition-colors">
            ← Back to home
          </Link>
        </div>
      </header>

      <main id="main-content" className="max-w-[760px] mx-auto px-6 py-16">
        {/* Page heading */}
        <div className="mb-14">
          <p className="text-xs font-medium tracking-[0.12em] uppercase text-[#FF7A33] mb-3">Legal</p>
          <h1 className="font-serif text-[52px] leading-[1.08] tracking-[-0.02em] text-[#1E0C16] mb-4">Terms of Use</h1>
          <p className="text-sm font-light text-[#A06A52]">Last updated: May 2, 2026</p>
        </div>

        {/* Intro */}
        <div className="space-y-4 mb-14 p-6 bg-white rounded-2xl border border-[#FFD9C2]">
          <P>
            These Terms of Use (&quot;Terms&quot;) govern your access to and use of the Vyla mobile application, the website at <strong>vyla.health</strong>, connected wearable features, AI features, reports, sharing tools, and related services (collectively, the &quot;Services&quot;).
          </P>
          <P>
            These Terms are a legal agreement between you and <strong>DemyCorp Ltd</strong>, trading as Vyla (&quot;Vyla,&quot; &quot;we,&quot; &quot;us,&quot; or &quot;our&quot;). By creating an account, using the Services, or clicking to accept these Terms, you agree to be bound by them.
          </P>
          <P>
            If you do not agree to these Terms, do not use the Services.
          </P>
        </div>

        {/* Section 1 */}
        <Section id="eligibility" title="1. Eligibility">
          <P>You may use the Services only if:</P>
          <Ul items={[
            "you are legally capable of entering into a binding agreement;",
            "you comply with these Terms and applicable law; and",
            "you are at least the minimum age required in your jurisdiction to use the Services.",
          ]} />
          <P>Vyla is not intended for children under 13. If a higher minimum age applies where you live, that higher age applies.</P>
        </Section>

        {/* Section 2 */}
        <Section id="privacy" title="2. Privacy and Related Policies">
          <P>
            Your use of the Services is also subject to our{" "}
            <Link href="/privacy" className="text-[#FF7A33] hover:text-[#e86a22] transition-colors underline underline-offset-2">
              Privacy Policy
            </Link>
            , available at <strong>vyla.health</strong> and in the app. The Privacy Policy explains how we collect, use, and disclose personal data.
          </P>
          <P>If there is a conflict between these Terms and the Privacy Policy on privacy matters, the Privacy Policy controls for those privacy matters.</P>
        </Section>

        {/* Section 3 */}
        <Section id="services" title="3. The Services">
          <P>Vyla is a reproductive health and wellness platform that may include features such as:</P>
          <Ul items={[
            "cycle, symptom, period, temperature, LH, cervical mucus, intimacy, mood, and wellness tracking;",
            "insights, predictions, summaries, and reports;",
            "Vyla AI chat and AI-assisted logging;",
            "wearable and Bluetooth device sync;",
            "report generation, secure links, and sharing tools;",
            "referral, friend, and comparison features; and",
            "subscription-based premium features.",
          ]} />
          <P>Features may vary by platform, country, device, subscription tier, language, or app version. We may add, remove, suspend, or modify features at any time.</P>
        </Section>

        {/* Section 4 */}
        <Section id="medical-disclaimer" title="4. Medical Disclaimer">
          <P>Vyla provides consumer wellness and educational tools. The Services are <strong>not</strong> medical care, a medical device, or a substitute for professional medical advice, diagnosis, or treatment.</P>
          <P>In particular:</P>
          <Ul items={[
            "Vyla AI responses may be incomplete, inaccurate, or unsuitable for your situation;",
            "cycle predictions and fertility-related insights are estimates, not guarantees;",
            "wearable data may be delayed, incomplete, or inaccurate; and",
            "LH image analysis, symptom summaries, and related outputs are informational only.",
          ]} />
          <div className="bg-[#FFF0E8] border border-[#FFD9C2] rounded-xl p-4">
            <p className="text-[14px] font-medium text-[#1E0C16]">Important</p>
            <p className="text-[14px] font-light text-[#3D1F2E] mt-1 leading-relaxed">Do not rely on the Services for emergencies. If you believe you may be having a medical emergency, call emergency services immediately and contact a qualified healthcare professional.</p>
          </div>
        </Section>

        {/* Section 5 */}
        <Section id="your-account" title="5. Your Account">
          <P>You may be able to use Vyla through:</P>
          <Ul items={[
            "an email/password account;",
            "a Google or Apple sign-in flow; or",
            "an anonymous or minimal-identity mode, if offered.",
          ]} />
          <P>You are responsible for:</P>
          <Ul items={[
            "providing accurate information where required;",
            "maintaining the confidentiality of your credentials, device access, and recovery information;",
            "all activity occurring under your account or session; and",
            "promptly notifying us if you suspect unauthorized access.",
          ]} />
          <P>If you use an anonymous account or recovery-phrase-based mode, you understand that the recovery phrase may be the only way to restore access if you lose your device or session. We are not responsible if you lose access because you did not securely retain your recovery credentials.</P>
        </Section>

        {/* Section 6 */}
        <Section id="sensitive-data" title="6. Consent to Sensitive Data Processing">
          <P>Because Vyla is centered on reproductive health and wellness, your use of the Services may involve the processing of sensitive data that you choose to submit, including cycle, symptom, temperature, fertility, wearable, or related health information.</P>
          <P>By using relevant features, you instruct us to process that information as necessary to provide those features, subject to our Privacy Policy and applicable law.</P>
        </Section>

        {/* Section 7 */}
        <Section id="vyla-ai" title="7. Vyla AI">
          <P>If you use Vyla AI features:</P>
          <Ul items={[
            "you authorize Vyla to process your prompts, messages, account context, and relevant health data to generate responses, suggestions, and structured outputs;",
            "chat history, thread history, outputs, and saved records may be stored with your account;",
            "AI features may ask follow-up questions or suggest updates to your logs; and",
            "you remain responsible for reviewing AI-generated outputs before relying on them or saving them to your records.",
          ]} />
          <P>You may not use Vyla AI to:</P>
          <Ul items={[
            "seek emergency guidance;",
            "submit unlawful, infringing, abusive, or harmful content;",
            "probe, reverse engineer, or overload the AI systems; or",
            "generate content for deceptive, fraudulent, or abusive purposes.",
          ]} />
        </Section>

        {/* Section 8 */}
        <Section id="wearables" title="8. Wearables and Device Connectivity">
          <P>If you connect a wearable or Bluetooth-enabled device, you authorize Vyla to pair with that device and process synced data and related device metadata to provide the feature.</P>
          <P>You are responsible for:</P>
          <Ul items={[
            "confirming that you are authorized to connect the device;",
            "keeping your device software and permissions current; and",
            "understanding that third-party wearable hardware and software are outside Vyla's control.",
          ]} />
          <P>We do not guarantee continuous compatibility with any device, operating system, or third-party wearable platform.</P>
        </Section>

        {/* Section 9 */}
        <Section id="reports-sharing" title="9. Reports, Sharing, and Social Features">
          <P>Vyla may allow you to generate reports, create shareable summaries, copy secure links, invite friends, compare selected metrics, or share content with healthcare providers, partners, or others.</P>
          <P>You are solely responsible for your decision to share information. Once you choose to share content outside the Services, Vyla cannot control how recipients store, forward, interpret, or use it.</P>
          <P>You agree not to:</P>
          <Ul items={[
            "share another person's information without appropriate authority;",
            "use friend, referral, or sharing features to harass, spam, or mislead others;",
            "attempt to access another user's private data; or",
            "misuse secure links or report exports.",
          ]} />
        </Section>

        {/* Section 10 */}
        <Section id="subscriptions" title="10. Paid Features and Subscriptions">
          <P>Some features may require a paid subscription or other payment.</P>
          <P>If you purchase a subscription:</P>
          <Ul items={[
            "you agree to pay all applicable fees, taxes, and charges disclosed at checkout;",
            "billing may be handled by Vyla, an app store, or third-party payment providers;",
            "your purchase may be subject to additional terms imposed by the applicable billing platform; and",
            "access to paid features may change if your subscription expires, is canceled, is refunded, or becomes delinquent.",
          ]} />
          <P>If your subscription is offered on a recurring basis, it may renew automatically unless canceled in accordance with the applicable billing platform&apos;s rules. You are responsible for managing cancellation through the relevant checkout provider, app store account, or any subscription settings we provide.</P>
          <P>Prices, plan features, trial availability, and country-specific billing options may change.</P>
        </Section>

        {/* Section 11 */}
        <Section id="acceptable-use" title="11. Acceptable Use">
          <P>You may not use the Services to:</P>
          <Ul items={[
            "violate any law or regulation;",
            "infringe intellectual property, privacy, publicity, or other rights;",
            "upload malicious code or interfere with the integrity or security of the Services;",
            "scrape, copy, mirror, or exploit the Services except as allowed by law;",
            "impersonate another person or misrepresent your affiliation;",
            "attempt to gain unauthorized access to accounts, systems, or data;",
            "use the Services to send spam, phishing messages, or abusive communications; or",
            "use the Services in a way that could harm Vyla, users, or third parties.",
          ]} />
        </Section>

        {/* Section 12 */}
        <Section id="your-content" title="12. Your Content">
          <P>You retain ownership of the information and content you submit to Vyla, including logs, images, notes, prompts, reports you generate, and other materials (&quot;User Content&quot;).</P>
          <P>You grant Vyla a worldwide, non-exclusive, royalty-free license to host, store, reproduce, process, adapt, transmit, and display User Content as necessary to:</P>
          <Ul items={[
            "operate and provide the Services;",
            "generate requested outputs, reports, and shares;",
            "maintain security and prevent abuse;",
            "comply with law; and",
            "improve and support the Services in ways described in the Privacy Policy and permitted by applicable law.",
          ]} />
          <P>You represent that you have all rights needed to submit User Content and that your User Content does not violate these Terms or applicable law.</P>
        </Section>

        {/* Section 13 */}
        <Section id="intellectual-property" title="13. Intellectual Property">
          <P>The Services, including the Vyla name, branding, software, design, interfaces, text, graphics, and other content provided by Vyla, are owned by Vyla or its licensors and are protected by intellectual property laws.</P>
          <P>Subject to these Terms, we grant you a limited, non-exclusive, non-transferable, revocable right to use the Services for your personal, non-commercial use.</P>
          <P>You may not copy, modify, distribute, sell, lease, reverse engineer, or create derivative works from the Services except as permitted by applicable law.</P>
        </Section>

        {/* Section 14 */}
        <Section id="third-party" title="14. Third-Party Services">
          <P>The Services may integrate with third parties such as:</P>
          <Ul items={[
            "Google or Apple sign-in;",
            "mobile app stores;",
            "payment processors;",
            "analytics, messaging, or notification providers;",
            "sharing channels such as email or messaging apps; and",
            "third-party wearable hardware or software.",
          ]} />
          <P>Those third-party services operate under their own terms and privacy policies, and Vyla is not responsible for them.</P>
        </Section>

        {/* Section 15 */}
        <Section id="availability" title="15. Service Availability and Changes">
          <P>We may, without liability and with or without notice:</P>
          <Ul items={[
            "modify, suspend, restrict, or discontinue any part of the Services;",
            "impose usage limits;",
            "update technical requirements for supported devices or software; or",
            "perform maintenance, security updates, or emergency fixes.",
          ]} />
          <P>We do not guarantee that the Services will always be available, uninterrupted, secure, accurate, or error-free.</P>
        </Section>

        {/* Section 16 */}
        <Section id="termination" title="16. Suspension and Termination">
          <P>We may suspend or terminate your access to some or all of the Services if:</P>
          <Ul items={[
            "you violate these Terms;",
            "we reasonably suspect fraud, abuse, or security risks;",
            "required by law or third-party platform rules; or",
            "continued access could create risk or liability for Vyla, users, or third parties.",
          ]} />
          <P>You may stop using the Services at any time. If you want to close your account or request deletion, you may use available in-app controls or contact us, subject to applicable law and our retention obligations.</P>
          <P>Termination does not affect provisions that by their nature should survive, including provisions on payments owed, intellectual property, disclaimers, limitation of liability, dispute terms, and indemnity.</P>
        </Section>

        {/* Section 17 */}
        <Section id="disclaimers" title="17. Disclaimers">
          <div className="bg-white border border-[#FFD9C2] rounded-xl p-5 space-y-4">
            <P>TO THE MAXIMUM EXTENT PERMITTED BY LAW, THE SERVICES ARE PROVIDED &quot;AS IS&quot; AND &quot;AS AVAILABLE,&quot; WITHOUT WARRANTIES OF ANY KIND, WHETHER EXPRESS, IMPLIED, STATUTORY, OR OTHERWISE.</P>
            <P>WITHOUT LIMITING THE FOREGOING, VYLA DISCLAIMS ALL IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, NON-INFRINGEMENT, AND QUIET ENJOYMENT, AND DOES NOT WARRANT THAT:</P>
            <Ul items={[
              "the Services will meet your requirements;",
              "the Services will be accurate, complete, or reliable;",
              "predictions, insights, or AI outputs will be medically valid or suitable for any decision;",
              "wearable sync will be uninterrupted or error-free; or",
              "defects will be corrected on any particular timeline.",
            ]} />
          </div>
          <P>Some jurisdictions do not allow certain disclaimers, so some of the above may not apply to you.</P>
        </Section>

        {/* Section 18 */}
        <Section id="liability" title="18. Limitation of Liability">
          <div className="bg-white border border-[#FFD9C2] rounded-xl p-5 space-y-4">
            <P>TO THE MAXIMUM EXTENT PERMITTED BY LAW, VYLA AND ITS AFFILIATES, LICENSORS, SERVICE PROVIDERS, AND PERSONNEL WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, OR FOR ANY LOSS OF DATA, PROFITS, REVENUE, GOODWILL, OR BUSINESS OPPORTUNITY, ARISING OUT OF OR RELATED TO THE SERVICES OR THESE TERMS.</P>
            <P>TO THE MAXIMUM EXTENT PERMITTED BY LAW, THE TOTAL LIABILITY OF VYLA FOR ALL CLAIMS ARISING OUT OF OR RELATING TO THE SERVICES OR THESE TERMS WILL NOT EXCEED THE GREATER OF:</P>
            <Ul items={[
              "the amount you paid to Vyla for the Services in the 12 months before the event giving rise to the claim; or",
              "USD $100.",
            ]} />
          </div>
          <P>Nothing in these Terms excludes or limits liability that cannot be excluded or limited under applicable law.</P>
        </Section>

        {/* Section 19 */}
        <Section id="indemnity" title="19. Indemnity">
          <P>To the extent permitted by law, you agree to indemnify and hold harmless Vyla and its affiliates, officers, directors, employees, contractors, and agents from and against claims, liabilities, damages, losses, and expenses arising out of or related to:</P>
          <Ul items={[
            "your use or misuse of the Services;",
            "your User Content;",
            "your violation of these Terms; or",
            "your violation of any law or the rights of a third party.",
          ]} />
        </Section>

        {/* Section 20 */}
        <Section id="disputes" title="20. Governing Law and Disputes">
          <P>These Terms are governed by the laws of <strong>[Insert Governing Law Jurisdiction]</strong>, excluding conflict-of-laws rules.</P>
          <P>Any dispute arising out of or relating to these Terms or the Services will be brought in the courts located in <strong>[Insert Venue]</strong>, unless applicable consumer law requires otherwise.</P>
          <P>Nothing in these Terms limits any non-waivable consumer rights you may have under the law of your country, state, or province of residence.</P>
        </Section>

        {/* Section 21 */}
        <Section id="changes" title="21. Changes to These Terms">
          <P>We may update these Terms from time to time. If we make material changes, we may provide notice through the Services, by email, on <strong>vyla.health</strong>, or by other reasonable means.</P>
          <P>Your continued use of the Services after updated Terms become effective means you accept the updated Terms.</P>
        </Section>

        {/* Section 22 */}
        <Section id="general" title="22. General Terms">
          <Ul items={[
            "You may not assign or transfer these Terms without our prior written consent.",
            "We may assign these Terms in connection with a merger, acquisition, reorganization, or sale of assets.",
            "If any provision of these Terms is found unenforceable, the remaining provisions will remain in effect.",
            "Our failure to enforce any provision is not a waiver.",
            "These Terms, together with any incorporated policies and any applicable purchase terms, form the entire agreement between you and Vyla regarding the Services.",
          ]} />
        </Section>

        {/* Section 23 */}
        <Section id="contact" title="23. Contact">
          <P>For questions about these Terms, contact DemyCorp Ltd:</P>
          <div className="bg-white border border-[#FFD9C2] rounded-xl p-5 space-y-1.5">
            {[
              ["Legal entity", "DemyCorp Ltd, trading as Vyla"],
              ["Website", "https://vyla.health"],
              ["Email", "legal@vyla.health"],
              ["Support", "support@vyla.health"],
              ["Address", "6 Giles Avenue, London RM13"],
            ].map(([k, v]) => (
              <div key={k} className="flex gap-3 text-[14px]">
                <span className="font-medium text-[#1E0C16] w-28 shrink-0">{k}</span>
                <span className="font-light text-[#A06A52]">{v}</span>
              </div>
            ))}
          </div>
        </Section>
      </main>

      {/* Footer */}
      <footer className="border-t border-[#FFD9C2] py-8">
        <div className="max-w-[760px] mx-auto px-6 flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-xs text-[#A06A52]">© 2026 DemyCorp Ltd. All rights reserved.</p>
          <Link href="/" className="text-xs font-medium text-[#FF7A33] hover:text-[#e86a22] transition-colors">
            ← Back to home
          </Link>
        </div>
      </footer>
    </div>
  );
}
