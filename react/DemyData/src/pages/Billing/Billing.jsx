// src/pages/billing/Billing.jsx
import React, { useState } from "react";
import DashboardLayout from "../../components/layouts/DashboardLayout";
import { loadStripe } from "@stripe/stripe-js";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";

const stripePromise = loadStripe(import.meta.env.VITE_STRIPE_PK || "");

const Billing = () => {
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState("");

  const subscribe = async () => {
    setError(""); setLoading(true);
    try {
      // Ask your backend to create a checkout session
      const { data } = await axiosInstance.post(API_PATHS.BILLING.CREATE_CHECKOUT, {
        price_id: "price_12345_premium_monthly", // <-- put your Stripe Price ID here
        // Optional overrides:
        // success_url, cancel_url
      });

      const stripe = await stripePromise;
      if (!stripe) throw new Error("Stripe not initialized. Check VITE_STRIPE_PK.");

      const sessionId = data?.id || data?.sessionId;
      if (!sessionId) throw new Error("No session id returned from server.");

      const { error } = await stripe.redirectToCheckout({ sessionId });
      if (error) throw error;
    } catch (e) {
      setError(e?.message || "Failed to start checkout.");
    } finally {
      setLoading(false);
    }
  };

  const manageBilling = async () => {
    setError(""); setLoading(true);
    try {
      const { data } = await axiosInstance.post(API_PATHS.BILLING.CUSTOMER_PORTAL, {});
      if (data?.url) window.location.href = data.url;
      else throw new Error("No portal URL returned from server.");
    } catch (e) {
      setError(e?.message || "Failed to open billing portal.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <DashboardLayout activeMenu="Billing">
      <div className="m-3 max-w-xl">
        <h1 className="text-2xl font-semibold">Billing</h1>
        <p className="text-sm text-gray-500 mt-1">
          Manage your subscription and invoices securely via Stripe.
        </p>

        {error && (
          <div className="mt-4 rounded-lg border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">{error}</div>
        )}

        <div className="mt-6 space-y-3">
          <button
            onClick={subscribe}
            disabled={loading}
            className="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
          >
            {loading ? "Redirecting…" : "Subscribe to Premium"}
          </button>

          <button
            onClick={manageBilling}
            disabled={loading}
            className="inline-flex items-center gap-2 rounded-lg border border-gray-300 px-4 py-2 text-sm font-medium text-gray-800 hover:bg-gray-50 disabled:opacity-60"
          >
            Manage billing
          </button>
        </div>

        <p className="text-xs text-gray-500 mt-4">
          You’ll be redirected to Stripe Checkout to complete your purchase.
        </p>
      </div>
    </DashboardLayout>
  );
};

export default Billing;
