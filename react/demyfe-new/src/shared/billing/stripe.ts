type StripeClient = {
  redirectToCheckout: (args: { sessionId: string }) => Promise<{ error?: { message?: string } }>;
};

declare global {
  interface Window {
    Stripe?: (publishableKey: string) => StripeClient;
  }
}

let stripePromise: Promise<StripeClient | null> | null = null;

const resolvePublishableKey = (): string => {
  const candidates = [
    process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY,
    process.env.NEXT_PUBLIC_STRIPE_PK,
  ].filter((value): value is string => typeof value === "string" && value.trim().length > 0);

  const key = candidates[0];
  if (!key) {
    throw new Error(
      "Stripe publishable key missing. Set NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY or NEXT_PUBLIC_STRIPE_PK.",
    );
  }
  return key.trim();
};

export const getStripe = () => {
  if (!stripePromise) {
    stripePromise = new Promise((resolve, reject) => {
      if (typeof window === "undefined") {
        resolve(null);
        return;
      }

      const key = resolvePublishableKey();
      const createClient = () => {
        if (!window.Stripe) {
          reject(new Error("Stripe.js failed to load."));
          return;
        }
        resolve(window.Stripe(key));
      };

      if (window.Stripe) {
        createClient();
        return;
      }

      const existing = document.querySelector<HTMLScriptElement>('script[data-stripe-js="true"]');
      if (existing) {
        existing.addEventListener("load", createClient, { once: true });
        existing.addEventListener("error", () => reject(new Error("Failed to load Stripe.js")), { once: true });
        return;
      }

      const script = document.createElement("script");
      script.src = "https://js.stripe.com/v3/";
      script.async = true;
      script.dataset.stripeJs = "true";
      script.addEventListener("load", createClient, { once: true });
      script.addEventListener("error", () => reject(new Error("Failed to load Stripe.js")), { once: true });
      document.head.appendChild(script);
    });
  }
  return stripePromise;
};
