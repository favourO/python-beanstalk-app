// src/pages/billing/Premium.jsx
import React, { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../../components/layouts/DashboardLayout";
import { LuCircleCheckBig, LuCloudUpload } from "react-icons/lu";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";
import { getStripe } from "../../utils/stripe";

const Feature = ({ children }) => (
  <li className="flex items-center gap-2">
    <LuCircleCheckBig className="shrink-0" /> <span>{children}</span>
  </li>
);

const Premium = () => {
  const navigate = useNavigate();
  const [plans, setPlans] = useState([]);
  const [me, setMe] = useState(null);
  const [loading, setLoading] = useState(false);
  const [portalLoading, setPortalLoading] = useState(false);
  const [err, setErr] = useState("");

  const successUrl = `${window.location.origin}/billing/success`;
  const cancelUrl = `${window.location.origin}/billing/cancel`;

  const fetchPlans = async () => {
    try {
      const res = await axiosInstance.get(API_PATHS.BILLING.PLANS);
      setPlans(Array.isArray(res.data) ? res.data : []);
    } catch (e) {
      // non-fatal
    }
  };

  const fetchMe = async () => {
    try {
      const res = await axiosInstance.get(API_PATHS.BILLING.ME);
      setMe(res.data);
    } catch (e) {
      // non-fatal
    }
  };

  useEffect(() => {
    fetchPlans();
    fetchMe();
  }, []);

  const startCheckout = async (plan) => {
    setLoading(true);
    setErr("");
    try {
      const res = await axiosInstance.post(API_PATHS.BILLING.CREATE_CHECKOUT, {
        plan,
        success_url: successUrl,
        cancel_url: cancelUrl,
      });
      const sessionId = res?.data?.session_id;
      if (!sessionId) throw new Error("No session id");
      const stripe = await getStripe();
      const { error } = await stripe.redirectToCheckout({ sessionId });
      if (error) setErr(error.message || "Stripe redirect failed");
    } catch (e) {
      setErr(
        e?.response?.data?.detail ||
          e?.response?.data?.message ||
          e?.message ||
          "Checkout failed"
      );
    } finally {
      setLoading(false);
    }
  };

  const openCustomerPortal = async () => {
    setPortalLoading(true);
    setErr("");
    try {
      const res = await axiosInstance.post(API_PATHS.BILLING.CUSTOMER_PORTAL, {
        return_url: window.location.href,
      });
      const url = res?.data?.url;
      if (!url) throw new Error("No portal url");
      window.location.assign(url);
    } catch (e) {
      setErr(
        e?.response?.data?.detail ||
          e?.response?.data?.message ||
          e?.message ||
          "Failed to open customer portal"
      );
    } finally {
      setPortalLoading(false);
    }
  };

  const planFree = {
    name: "Free",
    price: "£0/mo",
    features: [
      "5 uploads total",
      "Up to 10 MB total",
      "20 queries (Engine + Scientific) total",
    ],
  };

  const planBasic = plans.find((p) => p.name === "basic") || {
    name: "Basic",
    price: "£9.99/mo",
    features: ["1000 queries / month", "Up to 5 GB uploads monthly"],
  };

  const planPremium = plans.find((p) => p.name === "premium") || {
    name: "Premium",
    price: "£25/mo",
    features: ["Unlimited queries", "Up to 100 GB uploads monthly"],
  };

  const currentPlan =
    me?.plan || "free"; /* 'free' | 'basic' | 'premium' */

  return (
    <DashboardLayout activeMenu="Billing">
      <div className="m-3 max-w-5xl mx-auto">
        <div className="text-center mb-8">
          <h1 className="text-2xl md:text-3xl font-semibold">Upgrade</h1>
          <p className="text-sm text-gray-500 mt-2">
            Choose a plan that fits your workload. You can manage or cancel anytime.
          </p>
          {err && (
            <div className="mx-auto mt-3 max-w-xl rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
              {err}
            </div>
          )}
          {me && (
            <div className="mx-auto mt-3 max-w-xl rounded-md border border-blue-200 bg-blue-50 px-3 py-2 text-sm text-blue-800">
              Current plan: <span className="font-medium uppercase">{currentPlan}</span>
              {me.status ? ` • ${me.status}` : ""}
            </div>
          )}
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Free */}
          <div className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-lg font-medium">{planFree.name}</h3>
            <p className="text-3xl font-semibold mt-2">
              £0<span className="text-sm font-normal text-gray-500">/mo</span>
            </p>
            <ul className="mt-4 space-y-2 text-sm text-gray-700">
              {planFree.features.map((f, i) => (
                <Feature key={i}>{f}</Feature>
              ))}
            </ul>
            <button
              onClick={() => navigate("/admin/files")}
              className="mt-6 inline-flex items-center gap-2 rounded-lg bg-gray-200 px-4 py-2 text-sm font-medium text-gray-800 hover:bg-gray-300"
            >
              <LuCloudUpload /> Continue Free
            </button>
          </div>

          {/* Basic */}
          <div className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
            <h3 className="text-lg font-medium">Basic</h3>
            <p className="text-3xl font-semibold mt-2">
              {planBasic.price.replace("/month", "/mo")}
            </p>
            <ul className="mt-4 space-y-2 text-sm text-gray-700">
              {planBasic.features?.map((f, i) => (
                <Feature key={i}>{f}</Feature>
              ))}
            </ul>

            <button
              onClick={() => startCheckout("basic")}
              disabled={loading}
              className="mt-6 inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
            >
              <LuCloudUpload /> {loading ? "Processing…" : "Upgrade to Basic"}
            </button>
          </div>

          {/* Premium */}
          <div className="rounded-2xl border-2 border-indigo-500 bg-white p-6 shadow-md relative">
            <div className="absolute -top-3 right-4 rounded-full bg-indigo-600 px-3 py-1 text-xs text-white">
              Most popular
            </div>
            <h3 className="text-lg font-medium">Premium</h3>
            <p className="text-3xl font-semibold mt-2">
              {planPremium.price.replace("/month", "/mo")}
            </p>
            <ul className="mt-4 space-y-2 text-sm text-gray-700">
              {planPremium.features?.map((f, i) => (
                <Feature key={i}>{f}</Feature>
              ))}
            </ul>

            <button
              onClick={() => startCheckout("premium")}
              disabled={loading}
              className="mt-6 inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
            >
              <LuCloudUpload /> {loading ? "Processing…" : "Upgrade to Premium"}
            </button>

            {currentPlan !== "free" && (
              <button
                onClick={openCustomerPortal}
                disabled={portalLoading}
                className="mt-3 inline-flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-60"
              >
                {portalLoading ? "Opening…" : "Manage subscription"}
              </button>
            )}
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
};

export default Premium;
