import Link from "next/link";
import Image from "next/image";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "Learn how Vyla collects, uses, and protects your personal data. Your cycle data is never sold to advertisers. You can export or delete your data at any time.",
  alternates: { canonical: "https://vyla.health/privacy" },
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

function Sub({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mt-6">
      <h3 className="text-base font-semibold text-[#1E0C16] mb-3">{title}</h3>
      <div className="space-y-3">{children}</div>
    </div>
  );
}

function P({ children }: { children: React.ReactNode }) {
  return <p className="text-[15px] font-light text-[#3D1F2E] leading-relaxed">{children}</p>;
}

function Ul({ items }: { items: string[] }) {
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

function TableRow({ purpose, basis }: { purpose: string; basis: string }) {
  return (
    <tr className="border-b border-[#FFD9C2]/60">
      <td className="py-3 pr-6 text-[14px] font-light text-[#3D1F2E] leading-relaxed align-top">{purpose}</td>
      <td className="py-3 text-[14px] font-light text-[#3D1F2E] leading-relaxed align-top">{basis}</td>
    </tr>
  );
}

export default function PrivacyPage() {
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
          <h1 className="font-serif text-[52px] leading-[1.08] tracking-[-0.02em] text-[#1E0C16] mb-4">Privacy Policy</h1>
          <p className="text-sm font-light text-[#A06A52]">Last updated: May 8, 2026</p>
        </div>

        {/* Intro */}
        <div className="space-y-4 mb-14 p-6 bg-white rounded-2xl border border-[#FFD9C2]">
          <P>
            This Privacy Policy explains how <strong>DemyCorp Ltd</strong>, trading as Vyla ("Vyla," "we," "us," or "our") collects, uses, stores, discloses, protects, and otherwise processes personal data when you use the Vyla mobile application, Vyla AI, connected wearable features, reports, sharing tools, websites, subscription flows, support channels, and related services (collectively, the "Services").
          </P>
          <P>
            Vyla is a consumer cycle tracking and wellness app. It helps users log cycle information, symptoms, moods, temperature, LH tests, cervical mucus, intimacy, wearable signals, and related wellness information. Vyla may also provide cycle predictions, insights, reminders, reports, sharing tools, Vyla AI chat, AI-assisted logging, and subscription-based premium features.
          </P>
          <P>
            Vyla is not a medical device, medical service, health plan, healthcare provider, or substitute for professional medical advice, diagnosis, or treatment. The Services provide consumer wellness and informational features. If you have a medical concern, contact a qualified healthcare professional.
          </P>
          <P>
            This Privacy Policy is designed to be read together with our Terms of Use and any just-in-time notices, consent screens, permission prompts, app store disclosures, or feature-specific notices we provide.
          </P>
        </div>

        {/* Section 1 */}
        <Section id="summary" title="1. Quick Summary">
          <P>This summary is not a substitute for the full policy, but it highlights important points.</P>
          <Ul items={[
            "Vyla processes sensitive reproductive health and wellness data that you choose to provide, such as cycle logs, symptoms, temperature, LH test information, cervical mucus, intimacy logs, notes, AI messages, and wearable signals.",
            "We use your data to provide the Services, including account access, cycle tracking, predictions, insights, reminders, reports, AI features, wearable sync, subscriptions, support, security, and product improvement.",
            "Vyla AI chat requires Premium in the current app. If you use Vyla AI, your messages and relevant account or cycle context may be processed to generate responses and support chat history.",
            "If you connect a wearable, we process device metadata and synced wellness signals to show readings and support insights.",
            "We do not sell your reproductive health data to advertisers or data brokers.",
            "We do not currently describe Vyla as an ad-supported app, and the current mobile app codebase does not include third-party advertising SDKs.",
            "We share data with service providers only as needed to operate the Services, with payment providers to process subscriptions, with identity providers if you choose social sign-in, and with other people only when you choose to share or use social features.",
            "You may have rights to access, correct, delete, export, restrict, or object to certain processing of your data, depending on where you live.",
            "Some features are optional. You can choose whether to use Vyla AI, upload LH images, enable notifications, connect a wearable, invite friends, or share reports.",
          ]} />
        </Section>

        {/* Section 2 */}
        <Section id="contact" title="2. Who We Are and How to Contact Us">
          <P>The controller or business responsible for the processing described in this Privacy Policy is:</P>
          <div className="bg-white border border-[#FFD9C2] rounded-xl p-5 space-y-1.5">
            {[
              ["Legal entity", "DemyCorp Ltd, trading as Vyla"],
              ["Email", "privacy@vyla.health"],
              ["Support", "support@vyla.health"],
              ["Address", "6 Giles Avenue, London RM13"],
              ["Website", "https://vyla.health"],
            ].map(([k, v]) => (
              <div key={k} className="flex gap-3 text-[14px]">
                <span className="font-medium text-[#1E0C16] w-28 shrink-0">{k}</span>
                <span className="font-light text-[#A06A52]">{v}</span>
              </div>
            ))}
          </div>
          <P>If we appoint a Data Protection Officer, EU representative, UK representative, or other privacy contact, we will provide the details here.</P>
          <P>If you contact us about privacy, please do not include sensitive health information in the subject line of your email. We may need to verify your identity before responding to certain requests.</P>
        </Section>

        {/* Section 3 */}
        <Section id="scope" title="3. Scope of This Privacy Policy">
          <P>This Privacy Policy applies to personal data processed through:</P>
          <Ul items={[
            "the Vyla iOS and Android apps",
            "Vyla websites and landing pages",
            "Vyla backend services and APIs",
            "Vyla AI chat and AI-assisted logging features",
            "cycle, symptom, fertility, wellness, and health-data tracking features",
            "LH image capture, upload, and analysis features",
            "wearable, Bluetooth, and connected-device features",
            "notifications, reminders, and in-app messages",
            "subscriptions, plan selection, checkout, billing, and payment status workflows",
            "report generation, exports, secure links, share cards, email drafts, and sharing flows",
            "referral, invite, friend, and comparison features",
            "support, troubleshooting, security, diagnostics, and operational systems",
          ]} />
          <P>This Privacy Policy does not apply to third-party services that Vyla does not control, including app stores, operating system providers, third-party identity providers, payment processors, email providers, messaging apps, wearable vendors, AI infrastructure providers, analytics providers, or websites you access through external links.</P>
        </Section>

        {/* Section 4 */}
        <Section id="data-collected" title="4. Personal Data We Collect">
          <P>The data we collect depends on how you use Vyla, your device settings, your subscription, your country, and the features you choose.</P>

          <Sub title="4.1 Account and Identity Data">
            <Ul items={[
              "email address",
              "password credentials or password reset information",
              "first name and last name",
              "display name",
              "country",
              "date of birth or birth date",
              "account type, account mode, and signup method",
              "email verification status",
              "authentication tokens and session identifiers",
              "account IDs and user IDs",
              "consent records, including acceptance of terms, privacy notices, and feature-specific permissions",
              "social sign-in data from providers such as Google or Apple, including account identifiers, ID tokens, email address, and authentication metadata where provided by the identity provider",
            ]} />
          </Sub>

          <Sub title="4.2 Profile, Onboarding, and Cycle Setup Data">
            <Ul items={[
              "full name",
              "time zone",
              "locale and language",
              "country or region",
              "reproductive stage",
              "perimenopause settings",
              "tracking goals, such as cycle tracking, trying to conceive, avoiding pregnancy, or wellness awareness",
              "average cycle length",
              "average period length",
              "last period start and end dates",
              "years menstruating",
              "cycle regularity",
              "health conditions or context you choose to disclose",
              "privacy preferences, including settings related to research sharing, health analytics, personalization, product messaging, and optional feature participation where offered",
            ]} />
          </Sub>

          <Sub title="4.3 Cycle, Fertility, Symptom, and Wellness Logs">
            <Ul items={[
              "period start and end dates",
              "flow intensity",
              "flow color",
              "spotting",
              "cramps and pain levels",
              "symptoms",
              "mood",
              "energy level",
              "sleep quality",
              "stress-related entries",
              "cravings and appetite-related entries",
              "notes and free-text entries",
              "basal body temperature",
              "temperature measurement time, method, and quality factors",
              "LH test results",
              "LH test strip photos or images you capture or upload",
              "cervical mucus type, amount, and notes",
              "intimacy logs and related fertility context",
              "medication, supplement, or lifestyle information if you choose to enter it",
              "cycle day, phase, and cycle history",
              "predicted period dates",
              "fertile window and ovulation estimates",
              "cycle statistics, trends, and summaries",
              "reports, snapshots, and share cards generated from your data",
            ]} />
            <P>Some of this information may reveal or relate to reproductive health, sex life, fertility, pregnancy intentions, contraception, menstrual health, physical symptoms, mood, sleep, stress, or other sensitive personal information.</P>
          </Sub>

          <Sub title="4.4 Vyla AI Data">
            <Ul items={[
              "prompts and messages you send",
              "AI responses",
              "conversation titles, timestamps, and thread IDs",
              "chat history",
              "your current log state and relevant cycle context",
              "structured suggestions or extracted fields created from your messages",
              "missing-data prompts or follow-up questions",
              "feedback you provide on AI responses",
              "safety, moderation, and diagnostic metadata needed to operate the AI feature",
            ]} />
          </Sub>

          <Sub title="4.5 Wearable, Bluetooth, and Connected Device Data">
            <Ul items={[
              "wearable type, device name, model, and identifiers",
              "Bluetooth identifiers and pairing metadata",
              "battery status, sync status and timestamps",
              "firmware or hardware information",
              "steps, calories, distance",
              "heart rate and resting heart rate",
              "HRV or related recovery signals where available",
              "sleep duration and sleep-related values",
              "blood oxygen values where available",
              "temperature values",
              "stress values",
              "activity, recovery, or wellness summaries",
              "female health settings configured for a paired device",
              "raw or normalized data payload elements provided by the device or sync process",
            ]} />
          </Sub>

          <Sub title="4.6 Notification Data">
            <Ul items={[
              "push notification token",
              "device platform, app version, locale",
              "notification permission status and preferences",
              "quiet hours",
              "notification categories enabled or disabled",
              "notification history including type, title, body, delivery state, and read state",
            ]} />
          </Sub>

          <Sub title="4.7 Social, Referral, Invite, and Friend-Comparison Data">
            <Ul items={[
              "referral codes and invite links",
              "referral source metadata and deep-link identifiers",
              "friend request data and connection status",
              "email addresses or contact details you enter to invite someone",
              "comparison permissions and selected comparison metrics",
              "share IDs, share events, and secure link metadata",
              "report configuration choices and share method selected",
              "email subject and body text generated for a share flow",
            ]} />
            <P>Do not provide another person's contact details unless you have permission to do so.</P>
          </Sub>

          <Sub title="4.8 Subscription, Checkout, and Payment Data">
            <Ul items={[
              "subscription tier and plan selected",
              "billing interval and selected billing country",
              "local pricing information",
              "subscription status",
              "checkout session IDs",
              "payment provider customer IDs and subscription IDs",
              "provider price IDs",
              "payment confirmation metadata",
              "invoices, payment status, refund status, cancellation status, and renewal information",
            ]} />
          </Sub>

          <Sub title="4.9 Support and Communications Data">
            <Ul items={[
              "your name and email address",
              "support request content and attachments you provide",
              "account identifiers",
              "device and app details relevant to your request",
              "communications with our support team and records of our response",
            ]} />
          </Sub>

          <Sub title="4.10 Technical, Device, Usage, and Security Data">
            <Ul items={[
              "IP address and request metadata",
              "device type, operating system, app version",
              "browser type if you use web pages",
              "language, locale, and time zone",
              "diagnostic logs, crash or error information",
              "feature usage events",
              "referral and sharing analytics",
              "subscription and checkout flow events",
              "authentication, security, fraud, abuse, and rate-limit signals",
            ]} />
          </Sub>

          <Sub title="4.11 Local Device Data">
            <P>Vyla stores certain information locally on your device, which may include access tokens, user IDs, onboarding state, locale, notification preferences, AI permission preferences, wearable pairing details, and locally generated device identifiers. Some local data may remain on your device until you clear it, sign out, or uninstall the app.</P>
          </Sub>
        </Section>

        {/* Section 5 */}
        <Section id="sensitive-data" title="5. Sensitive Data and Consumer Health Data">
          <P>Vyla is built around reproductive health and wellness. Many categories of data described in this policy may be considered sensitive personal data, special category data, consumer health data, or health-related personal information under applicable laws. This may include:</P>
          <Ul items={[
            "period and menstrual cycle data",
            "fertility, ovulation, and pregnancy-intention information",
            "LH test results and images",
            "cervical mucus information",
            "intimacy logs",
            "symptoms and pain entries",
            "mood and stress information",
            "sleep and wearable signals",
            "AI messages about your body, health, cycle, symptoms, sex life, fertility, or wellness",
            "reports, summaries, and predictions derived from your logs",
          ]} />
          <P>We process this information to provide features you request, operate and secure the Services, and carry out other purposes described in this Privacy Policy. We do not use sensitive reproductive health information for third-party targeted advertising.</P>
        </Section>

        {/* Section 6 */}
        <Section id="collection" title="6. How We Collect Data">
          <P>We collect data:</P>
          <Ul items={[
            "directly from you when you create an account, complete onboarding, log information, use Vyla AI, upload images, connect devices, manage subscriptions, request support, invite friends, generate reports, or change settings",
            "automatically from your device and app session when you use the Services",
            "from connected devices and wearables you choose to pair",
            "from third-party sign-in providers if you use Google, Apple, or another supported identity provider",
            "from payment providers, app stores, or checkout providers when you select or purchase a subscription",
            "from notification, analytics, hosting, security, support, and infrastructure providers that help operate the Services",
            "from other users if they invite you, send you a friend request, share content with you, or participate in comparison features with you",
          ]} />
        </Section>

        {/* Section 7 */}
        <Section id="use" title="7. How We Use Data">
          <P>We use personal data for the following purposes.</P>
          <Sub title="7.1 Provide and Operate the Services">
            <Ul items={[
              "create and maintain accounts, authenticate users, verify email addresses",
              "complete onboarding and store and display logs",
              "calculate cycle day and cycle phase",
              "provide calendar and period tracking",
              "provide fertile window and ovulation estimates",
              "generate predictions and insights",
              "show dashboards, reports, summaries, and trend views",
              "process LH images and test results",
              "sync wearable data",
              "provide Vyla AI chat and AI-assisted logging",
              "generate exports and shareable reports",
              "deliver notifications and reminders",
              "support Premium features and manage subscription access",
            ]} />
          </Sub>
          <Sub title="7.2 Personalize and Improve Your Experience">
            <Ul items={[
              "remember your preferences",
              "tailor content to your cycle history and goals",
              "provide more relevant reminders",
              "improve predictions as your logged history grows",
              "show feature access based on your subscription tier",
              "localize pricing, language, and app experience by country or locale",
            ]} />
          </Sub>
          <Sub title="7.3 Operate Vyla AI">
            <Ul items={[
              "process your prompts and retrieve relevant context from your logs where appropriate",
              "generate responses and maintain conversation history",
              "create structured logging suggestions",
              "identify missing information needed to answer your question",
              "monitor, debug, and improve AI reliability and safety",
              "enforce safety rules and prevent misuse",
            ]} />
            <P>Unless we state otherwise or obtain appropriate permission, Vyla does not use your identifiable reproductive health data to train public AI models.</P>
          </Sub>
          <Sub title="7.4 Provide Wearable and Connected Device Features">
            <Ul items={[
              "pair and reconnect devices",
              "sync health and wellness readings and show readings in the app",
              "upload synced data to Vyla's backend",
              "support predictions, dashboards, reports, and insights where applicable",
              "troubleshoot sync issues",
            ]} />
          </Sub>
          <Sub title="7.5 Process Subscriptions and Payments">
            <Ul items={[
              "show localized plan offers and save Free or Premium plan selections",
              "create checkout sessions and confirm payments",
              "activate or revoke Premium access",
              "process renewals, cancellations, refunds, or payment failures",
              "prevent billing fraud",
              "comply with tax, accounting, and legal obligations",
            ]} />
          </Sub>
          <Sub title="7.6 Communicate With You">
            <Ul items={[
              "send account and security messages",
              "deliver push notifications if enabled",
              "respond to support requests",
              "send subscription or payment notices",
              "notify you about material policy changes",
            ]} />
          </Sub>
          <Sub title="7.7 Safety, Security, Fraud Prevention, and Compliance">
            <Ul items={[
              "secure accounts and detect suspicious activity",
              "prevent fraud, abuse, spam, and unauthorized access",
              "debug errors and maintain audit logs",
              "enforce terms and policies",
              "comply with law, court orders, regulatory requests, tax requirements, and legal claims",
            ]} />
          </Sub>
          <Sub title="7.8 Analytics and Product Improvement">
            <P>We use limited analytics and operational telemetry to understand feature usage, measure app reliability, improve onboarding and subscription flows, evaluate sharing and referral features, diagnose crashes and errors, and prioritize product improvements. We aim to use aggregated, pseudonymized, or de-identified data where practical.</P>
          </Sub>
        </Section>

        {/* Section 8 */}
        <Section id="legal-bases" title="8. Legal Bases for Processing">
          <P>If you are in the UK, EEA, or another jurisdiction that requires a legal basis, we generally rely on the following bases.</P>
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b-2 border-[#FFD9C2]">
                  <th className="pb-3 pr-6 text-[13px] font-semibold text-[#1E0C16] uppercase tracking-wide">Purpose</th>
                  <th className="pb-3 text-[13px] font-semibold text-[#1E0C16] uppercase tracking-wide">Legal basis</th>
                </tr>
              </thead>
              <tbody>
                <TableRow purpose="Account creation, sign-in, onboarding, cycle tracking, predictions, logs, reports, subscriptions, and core app features" basis="Performance of a contract with you" />
                <TableRow purpose="Processing reproductive health and wellness information you choose to log" basis="Your explicit request to provide the feature, explicit consent where required, performance of a contract where permitted, and other applicable lawful bases" />
                <TableRow purpose="Vyla AI chat and AI-assisted logging" basis="Performance of a contract, consent or explicit consent where required, and your request to use the feature" />
                <TableRow purpose="Wearable and Bluetooth sync" basis="Consent for device permissions where required and performance of a contract for the connected feature" />
                <TableRow purpose="Push notifications" basis="Consent or permission where required" />
                <TableRow purpose="Security, fraud prevention, service reliability, diagnostics, and abuse prevention" basis="Legitimate interests and legal obligations" />
                <TableRow purpose="Payment, tax, accounting, and subscription records" basis="Performance of a contract and legal obligations" />
                <TableRow purpose="Product analytics and service improvement" basis="Legitimate interests, consent where required, and user preferences where offered" />
                <TableRow purpose="Responding to privacy requests, legal claims, regulatory requests, and law enforcement" basis="Legal obligations, legitimate interests, and legal claims" />
              </tbody>
            </table>
          </div>
          <P>Where we rely on consent, you may withdraw consent at any time. Withdrawal does not affect processing that occurred before withdrawal and may affect your ability to use certain features.</P>
        </Section>

        {/* Section 9 */}
        <Section id="required-data" title="9. When You Must Provide Data">
          <P>Some data is required to use parts of the Services. For example:</P>
          <Ul items={[
            "an email address or supported sign-in credential may be required for a standard account",
            "cycle setup information may be required to generate cycle estimates",
            "payment information is required to purchase Premium",
            "push notification permission is required to receive push notifications",
            "Bluetooth permission is required for certain wearable features",
            "relevant logs may be required for useful predictions, reports, or AI answers",
          ]} />
          <P>If you do not provide required data, the relevant feature may not work. Optional data can be skipped, but skipping it may reduce the accuracy, relevance, or availability of some features.</P>
        </Section>

        {/* Section 10 */}
        <Section id="sharing" title="10. How We Share Data">
          <P>We may disclose personal data to the following categories of recipients.</P>
          <Sub title="10.1 Service Providers and Processors">
            <P>We use vendors that help us operate the Services, such as cloud hosting, database, authentication, analytics, crash-reporting, push notification, email, support, security, AI infrastructure, file generation, report generation, image processing, payment processors, and checkout providers. These providers may process data only for the purposes we authorize and subject to contractual obligations where required by law.</P>
          </Sub>
          <Sub title="10.2 Identity Providers">
            <P>If you sign in with Google, Apple, or another identity provider, we exchange information with that provider to authenticate you. The identity provider may process data under its own privacy policy.</P>
          </Sub>
          <Sub title="10.3 Payment Providers and App Stores">
            <P>If you purchase Premium or use a checkout flow, we may share or receive information from payment providers such as Stripe, Flutterwave, app stores, banks, card networks, or equivalent billing platforms. These parties may process your payment information under their own terms and privacy policies.</P>
          </Sub>
          <Sub title="10.4 AI Providers">
            <P>If Vyla AI is powered by third-party AI infrastructure, we may send prompts, relevant context, and metadata needed to generate responses, maintain safety, and operate the feature. We do not authorize AI providers to use identifiable Vyla user health data for their own advertising.</P>
          </Sub>
          <Sub title="10.5 Other Users and Recipients You Choose">
            <P>We may share data with others when you choose to send an invitation, send or accept a friend request, enable comparison features, generate a share card, create a secure link, export a report, or share a report with a healthcare professional, partner, friend, family member, or other recipient.</P>
            <P>Once information leaves Vyla through a recipient or third-party channel you choose, Vyla cannot control how that recipient or channel uses, stores, forwards, or protects it.</P>
          </Sub>
          <Sub title="10.6 Legal, Safety, and Corporate Disclosures">
            <Ul items={[
              "to comply with law, regulation, legal process, or enforceable government request",
              "to protect rights, privacy, safety, or property",
              "to investigate fraud, security incidents, abuse, or technical issues",
              "to enforce our Terms of Use or other agreements",
              "to professional advisors, auditors, insurers, regulators, courts, or law enforcement",
              "in connection with a merger, acquisition, financing, restructuring, bankruptcy, sale of assets, or similar transaction",
            ]} />
          </Sub>
        </Section>

        {/* Section 11 */}
        <Section id="what-we-dont-do" title="11. What We Do Not Do">
          <Ul items={[
            "sell your reproductive health data to advertisers or data brokers",
            "use your sensitive reproductive health data for third-party targeted advertising",
            "require you to use Vyla AI, upload LH images, enable notifications, connect a wearable, or use friend-comparison features",
            "provide medical diagnosis or emergency care",
            "knowingly collect personal data from children under 13",
          ]} />
          <P>If our practices change in a way that requires additional notice or consent, we will provide that notice or request that consent as required by law.</P>
        </Section>

        {/* Section 12 */}
        <Section id="vyla-ai" title="12. Vyla AI">
          <P>Vyla AI is intended to help you understand your logs, ask general cycle and wellness questions, and organize information. Vyla AI is not a clinician and does not provide medical advice, diagnosis, or treatment.</P>
          <P>When you use Vyla AI:</P>
          <Ul items={[
            "your message and relevant app context may be processed to generate a response",
            "your chat history may be stored with your account",
            "AI outputs may be inaccurate, incomplete, or unsuitable for your situation",
            "you are responsible for deciding whether to save any AI-assisted log suggestion",
            "sensitive information you type into chat may be processed as described in this policy",
            "we may use safety systems, moderation, logging, or review processes to prevent misuse and improve reliability",
          ]} />
          <div className="bg-[#FFF0E8] border border-[#FFD9C2] rounded-xl p-4">
            <p className="text-[14px] font-medium text-[#1E0C16]">Important</p>
            <p className="text-[14px] font-light text-[#3D1F2E] mt-1 leading-relaxed">Do not use Vyla AI for emergencies. If you have severe symptoms, unusual bleeding, persistent pain, pregnancy concerns, mental health crisis concerns, or urgent health questions, contact a qualified healthcare professional or emergency services.</p>
          </div>
        </Section>

        {/* Section 13 */}
        <Section id="lh-images" title="13. LH Images and Camera or Photo Access">
          <P>If you use LH image features, Vyla may request camera or photo permissions and process images you capture or upload. We use LH images to confirm image validity, analyze or help record LH test results, save the result to your log if you choose, troubleshoot image processing failures, and improve reliability where permitted.</P>
          <P>You can choose manual LH entry if available. You can manage camera and photo permissions through your device settings.</P>
        </Section>

        {/* Section 14 */}
        <Section id="notifications" title="14. Notifications and Reminders">
          <P>Vyla may offer notifications for period reminders, fertile window reminders, cycle delay alerts, ovulation-related updates, logging reminders, wearable sync reminders, subscription events, account messages, and similar app-related notices.</P>
          <P>Notification content may reveal sensitive cycle or wellness information to anyone who can see your device. You can manage notifications in the app and through your device settings.</P>
        </Section>

        {/* Section 15 */}
        <Section id="reports" title="15. Reports, Exports, Sharing, and Secure Links">
          <P>Vyla may let you generate cycle reports, health data reports, share cards, summaries, secure links, or email drafts. These outputs may include sensitive data selected by you or generated from your logs.</P>
          <P>Use care when sharing reports or links. Recipients may store, forward, screenshot, copy, or misunderstand the information. Vyla cannot control external recipients or external apps once you share information.</P>
        </Section>

        {/* Section 16 */}
        <Section id="friends" title="16. Friend, Referral, and Comparison Features">
          <P>If you invite someone, accept a friend request, or use comparison features, Vyla may process information about both users involved. Comparison features should be used only with people you trust.</P>
          <P>Depending on the feature, we may show summary-level information rather than raw logs. Even summary information can be sensitive. You can manage friend or comparison permissions where the app provides those controls.</P>
        </Section>

        {/* Section 17 */}
        <Section id="analytics" title="17. Analytics, Research, and De-Identified Data">
          <P>We may create aggregated, anonymized, or de-identified data from personal data so that it no longer reasonably identifies you. We may use such data for analytics, research, product development, benchmarking, reliability, and business purposes.</P>
          <P>Where we describe data as de-identified, we intend to maintain it in de-identified form and not attempt to re-identify it except as permitted by law.</P>
        </Section>

        {/* Section 18 */}
        <Section id="cookies" title="18. Cookies, SDKs, and Similar Technologies">
          <P>The primary Vyla product is a mobile app, but we may also operate websites, landing pages, checkout flows, support pages, secure links, or browser-based features.</P>
          <P>We and our service providers may use cookies, local storage, mobile SDKs, device identifiers, pixels or similar technologies, session tokens, analytics events, and crash logs for authentication, session continuity, security, analytics, checkout, fraud prevention, feature delivery, and preference storage. Where required, we provide consent choices for non-essential cookies or similar technologies.</P>
        </Section>

        {/* Section 19 */}
        <Section id="advertising" title="19. Advertising and Marketing">
          <P>The current Vyla app is not described as ad-supported, and the current mobile codebase does not include third-party advertising SDKs. We do not use sensitive reproductive health data for third-party targeted advertising.</P>
          <P>We may send service-related communications, such as account, security, billing, support, or policy notices. We may send marketing communications only where permitted by law and with required choices. You can opt out of marketing emails where offered.</P>
        </Section>

        {/* Section 20 */}
        <Section id="retention" title="20. Data Retention">
          <P>We retain personal data for as long as reasonably necessary for the purposes described in this Privacy Policy, including to provide the Services, maintain your account, support tracking history, preserve preferences and consents, meet legal obligations, prevent fraud, resolve disputes, and enforce agreements.</P>
          <Ul items={[
            "Account and profile data may be retained while your account is active and for a reasonable period afterward",
            "Cycle, wellness, symptom, fertility, and wearable records may be retained until you delete them or request deletion, subject to legal exceptions",
            "AI chat history may be retained while associated with your account unless deleted under our retention practices",
            "Subscription and payment records may be retained for tax, accounting, dispute, refund, fraud prevention, and compliance purposes",
            "Security logs, audit logs, backups, and diagnostic records may be retained for limited periods consistent with security and operational needs",
            "De-identified or aggregated data may be retained for longer because it is no longer reasonably associated with you",
          ]} />
        </Section>

        {/* Section 21 */}
        <Section id="security" title="21. Data Security">
          <P>We use administrative, technical, and organizational safeguards designed to protect personal data, including encryption in transit and at rest where appropriate, secure token storage, authenticated API access, access controls, environment separation, logging and monitoring, rate limiting, secure development practices, vendor review, and incident response processes.</P>
          <P>No method of transmission or storage is completely secure. You also play an important role by securing your device, using strong credentials, keeping recovery information safe, updating your app, managing lock-screen notification visibility, and sharing reports only with trusted recipients.</P>
        </Section>

        {/* Section 22 */}
        <Section id="transfers" title="22. International Data Transfers">
          <P>Vyla may process, store, or transfer personal data in countries other than the country where you live. These countries may have privacy laws that differ from those in your jurisdiction.</P>
          <P>Where required, we use appropriate safeguards for international transfers, such as adequacy decisions, standard contractual clauses, data processing agreements, transfer risk assessments, or other lawful transfer mechanisms.</P>
        </Section>

        {/* Section 23 */}
        <Section id="choices" title="23. Your Choices and Controls">
          <P>Depending on the feature and your jurisdiction, you may be able to:</P>
          <Ul items={[
            "update account and profile information",
            "choose what cycle and wellness data to log",
            "choose whether to use Vyla AI, upload LH images, or connect a wearable",
            "manage Bluetooth, camera, photo, and notification permissions through your device",
            "manage in-app notification preferences and quiet hours where available",
            "choose whether to use friend, referral, comparison, report, export, or sharing features",
            "manage privacy preferences where offered",
            "change subscription settings or sign out",
            "request access, correction, deletion, or export of your data",
            "delete your account where available",
          ]} />
        </Section>

        {/* Section 24 */}
        <Section id="rights" title="24. Your Privacy Rights">
          <P>Depending on where you live, you may have rights including:</P>
          <Ul items={[
            "the right to know or be informed about how we process personal data",
            "the right to access personal data",
            "the right to receive a copy of personal data",
            "the right to correct inaccurate personal data",
            "the right to delete personal data, subject to exceptions",
            "the right to data portability",
            "the right to object to certain processing",
            "the right to restrict certain processing",
            "the right to withdraw consent where processing is based on consent",
            "the right to limit certain uses or disclosures of sensitive personal data where applicable",
            "the right to opt out of certain sales, sharing, targeted advertising, profiling, or automated decision-making where applicable",
            "the right not to be discriminated against for exercising privacy rights",
            "the right to appeal a decision regarding your request where applicable",
          ]} />
          <P>To exercise rights, contact us at privacy@vyla.health or support@vyla.health. We may need to verify your identity before acting on a request.</P>
        </Section>

        {/* Section 25 */}
        <Section id="automated" title="25. Automated Processing, Predictions, and Profiling">
          <P>Vyla uses automated processing to provide features such as cycle day calculation, period predictions, fertile window estimates, ovulation estimates, symptom and trend summaries, wearable-based wellness insights, notification timing, AI responses and AI-assisted logging suggestions, and subscription access rules.</P>
          <P>These features are informational and are not intended to make legally significant decisions about you. Predictions and AI outputs may be inaccurate or incomplete. You should not rely on them for medical decisions.</P>
        </Section>

        {/* Section 26 */}
        <Section id="uk-eea" title="26. UK and EEA Privacy Notice">
          <P>If you are in the United Kingdom or European Economic Area, this section supplements the rest of this Privacy Policy.</P>
          <Sub title="Controller">
            <P>The controller is DemyCorp Ltd, trading as Vyla.</P>
          </Sub>
          <Sub title="Special Category Data">
            <P>Health, reproductive, sex life, biometric, or similar sensitive information may be special category data. We process this information only where a lawful basis and applicable special category condition are available, such as explicit consent, your request to provide the Services, legal claims, substantial public interest where applicable, vital interests, or another condition permitted by law.</P>
          </Sub>
          <Sub title="Your Rights">
            <P>You may have rights to access, rectification, erasure, restriction, portability, objection, withdrawal of consent, and rights related to automated decision-making.</P>
          </Sub>
          <Sub title="Complaints">
            <P>If you are in the UK, you may complain to the Information Commissioner's Office at https://ico.org.uk/. If you are in the EEA, you may complain to your local data protection supervisory authority. We encourage you to contact us first so we can try to resolve your concern.</P>
          </Sub>
        </Section>

        {/* Section 27 */}
        <Section id="us-states" title="27. United States State Privacy Notice">
          <P>If you are a resident of a U.S. state with an applicable consumer privacy law, this section supplements the rest of this Privacy Policy.</P>
          <Sub title="Categories of Personal Information">
            <Ul items={[
              "Identifiers, such as name, email address, account ID, device ID, and IP address",
              "Customer records, such as account, subscription, and support information",
              "Protected classification information if you provide it, such as age, sex-related information, or reproductive health context",
              "Commercial information, such as subscription selection, payment status, plan, renewal, cancellation, and purchase history",
              "Internet or electronic network activity, such as app usage, device, log, and diagnostic data",
              "Geolocation-related information at country, region, time zone, or IP-derived level",
              "Sensory information, such as LH test images you upload or capture",
              "Inferences, such as cycle trends, prediction outputs, and wellness insights",
              "Sensitive personal information or consumer health data, such as reproductive health, menstrual cycle, fertility, symptoms, mood, wearable health signals, AI messages, and account credentials",
            ]} />
          </Sub>
          <Sub title="Sales, Sharing, and Targeted Advertising">
            <P>We do not sell sensitive reproductive health data for money. We do not use sensitive reproductive health data for third-party targeted advertising. If we later engage in activities that are considered a "sale," "sharing," targeted advertising, or similar regulated disclosure under applicable state law, we will provide required notices and opt-out controls.</P>
          </Sub>
          <Sub title="State Privacy Rights">
            <P>Depending on your state, you may have rights to confirm processing, access, delete, correct, obtain a portable copy, opt out of certain processing, limit certain sensitive data uses, and appeal denied requests. Contact us using the details in Section 2 to exercise these rights.</P>
          </Sub>
        </Section>

        {/* Section 28 */}
        <Section id="california" title="28. California Privacy Notice">
          <P>If you are a California resident, this section supplements the rest of this Privacy Policy and applies to personal information under the California Consumer Privacy Act, as amended.</P>
          <Sub title="Sale or Sharing">
            <P>Vyla does not currently sell personal information for money or share sensitive reproductive health data for cross-context behavioral advertising. If this changes, we will provide required notices and choices.</P>
          </Sub>
          <Sub title="Your California Rights">
            <P>California residents may have the right to know, access, correct, delete, obtain a portable copy, limit certain uses of sensitive personal information, opt out of sale or sharing where applicable, and not be discriminated against for exercising rights. You may also use an authorized agent where permitted by law.</P>
          </Sub>
        </Section>

        {/* Section 29 */}
        <Section id="consumer-health" title="29. Consumer Health Data Notice">
          <P>Some laws define "consumer health data" broadly. Where such laws apply, Vyla may collect consumer health data including menstrual cycle data, fertility and ovulation information, pregnancy-intention information you provide, symptoms, mood, sleep, pain, temperature, LH, cervical mucus, intimacy, and wellness logs, wearable health and wellness signals, AI messages about health or wellness, and inferred cycle, fertility, and wellness insights.</P>
          <P>You may have rights to access, delete, withdraw consent, or appeal decisions regarding consumer health data depending on where you live.</P>
        </Section>

        {/* Section 30 */}
        <Section id="children" title="30. Children and Teens">
          <P>Vyla is not intended for children under 13, and we do not knowingly collect personal data from children under 13 without legally valid authorization. If a higher minimum age applies where you live, that higher age applies.</P>
          <P>If you believe a child has provided personal data to Vyla in violation of applicable law, contact us so we can investigate and take appropriate action.</P>
        </Section>

        {/* Section 31 */}
        <Section id="hipaa" title="31. HIPAA and Healthcare Providers">
          <P>Vyla is a consumer wellness app. Unless we expressly state otherwise in a separate written agreement, Vyla is not acting as a HIPAA covered entity or business associate when you use the consumer app.</P>
          <P>If you choose to share a Vyla report with a healthcare provider, that provider's handling of the report may be subject to separate health privacy laws and the provider's own policies.</P>
        </Section>

        {/* Section 32 */}
        <Section id="changes" title="32. Changes to This Privacy Policy">
          <P>We may update this Privacy Policy from time to time. If we make material changes, we may notify you through the app, by email, through our website, or by other reasonable means. The "Last updated" date shows when this version was last revised.</P>
          <P>Your continued use of the Services after an updated Privacy Policy becomes effective means your data will be processed under the updated policy to the extent permitted by law. If we need consent for a new processing activity, we will request it.</P>
        </Section>

        {/* Section 33 */}
        <Section id="contact-us" title="33. Contact Us">
          <P>For privacy questions, requests, or complaints, contact:</P>
          <div className="bg-white border border-[#FFD9C2] rounded-xl p-5 space-y-1.5">
            {[
              ["Legal entity", "DemyCorp Ltd, trading as Vyla"],
              ["Email", "privacy@vyla.health"],
              ["Support", "support@vyla.health"],
              ["Address", "6 Giles Avenue, London RM13"],
              ["Website", "https://vyla.health"],
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
