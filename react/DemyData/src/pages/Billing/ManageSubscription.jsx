// src/pages/billing/ManageSubscription.jsx
import React, { useEffect, useMemo, useState } from "react";
import DashboardLayout from "../../components/layouts/DashboardLayout";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";
import { getStripe } from "../../utils/stripe";
import {
  LuRefreshCw,
  LuCrown,
  LuArrowRightLeft,
  LuCircleCheckBig,
  LuCircle,
  LuClock4,
} from "react-icons/lu";

const formatBytes = (bytes) => {
  if (bytes == null) return "-";
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.floor(Math.log(Math.max(bytes, 1)) / Math.log(k));
  return `${(bytes / Math.pow(k, i)).toFixed(i === 0 ? 0 : 1)} ${sizes[i]}`;
};

const clamp = (n, a, b) => Math.max(a, Math.min(b, n));

const Progress = ({ used, limit, label }) => {
  if (limit == null || limit <= 0) {
    return (
      <div className="text-sm text-gray-600">
        {label}: <span className="font-medium">Unlimited</span>
      </div>
    );
  }
  const pct = clamp(Math.round((100 * (used || 0)) / limit), 0, 100);
  return (
    <div>
      <div className="flex items-center justify-between text-xs text-gray-600">
        <span>{label}</span>
        <span className="font-medium">
          {(used || 0).toLocaleString()} / {limit.toLocaleString()} ({pct}%)
        </span>
      </div>
      <div className="mt-1 h-2 w-full overflow-hidden rounded-full bg-gray-200">
        <div
          className={`h-2 rounded-full ${
            pct >= 90 ? "bg-red-500" : pct >= 70 ? "bg-amber-500" : "bg-indigo-600"
          }`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
};

const ByteProgress = ({ used, limit, label }) => {
  if (limit == null || limit <= 0) {
    return (
      <div className="text-sm text-gray-600">
        {label}: <span className="font-medium">Unlimited</span>
      </div>
    );
  }
  const pct = clamp(Math.round((100 * (used || 0)) / limit), 0, 100);
  return (
    <div>
      <div className="flex items-center justify-between text-xs text-gray-600">
        <span>{label}</span>
        <span className="font-medium">
          {formatBytes(used || 0)} / {formatBytes(limit)} ({pct}%)
        </span>
      </div>
      <div className="mt-1 h-2 w-full overflow-hidden rounded-full bg-gray-200">
        <div
          className={`h-2 rounded-full ${
            pct >= 90 ? "bg-red-500" : pct >= 70 ? "bg-amber-500" : "bg-indigo-600"
          }`}
          style={{ width: `${pct}%` }}
        />
      </div>
    </div>
  );
};

const PlanBadge = ({ name }) => (
  <span className="rounded-full bg-indigo-50 px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-indigo-700">
    {name}
  </span>
);

const ManageSubscription = () => {
  const [plans, setPlans] = useState([]);
  const [me, setMe] = useState(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");

  // cancel state
  const [atPeriodEnd, setAtPeriodEnd] = useState(true);
  const [cancelResult, setCancelResult] = useState(null);

  const successUrl = `${window.location.origin}/billing/success`;
  const cancelUrl = `${window.location.origin}/billing/cancel`;

  console.log("me", me);
  const currentPlan = (me?.plan || "free").toLowerCase();

  const load = async () => {
    setLoading(true);
    setErr("");
    try {
      const [pRes, mRes] = await Promise.all([
        axiosInstance.get(API_PATHS.BILLING.PLANS).catch(() => ({ data: [] })),
        axiosInstance.get(API_PATHS.BILLING.ME),
      ]);
      setPlans(Array.isArray(pRes.data) ? pRes.data : []);
      setMe(mRes.data || null);
    } catch (e) {
      setErr(
        e?.response?.data?.detail ||
          e?.message ||
          "Failed to load subscription."
      );
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const planMeta = useMemo(() => {
    const byName = {};
    (plans || []).forEach((p) => (byName[(p?.name || "").toLowerCase()] = p));
    return {
      free: byName["free"] || {
        name: "free",
        price: "£0/mo",
        features: [
          "5 data uploads total (10 MB)",
          "20 total queries (Engine + Scientific)",
        ],
      },
      basic: byName["basic"] || {
        name: "basic",
        price: "£9.99/mo",
        features: ["1000 queries / month", "Up to 5 GB uploads monthly"],
      },
      premium: byName["premium"] || {
        name: "premium",
        price: "£25/mo",
        features: ["Unlimited queries", "Up to 100 GB uploads monthly"],
      },
    };
  }, [plans]);

  const startCheckout = async (plan) => {
    setBusy(true);
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
      setBusy(false);
    }
  };

  const cancelSubscription = async () => {
    setBusy(true);
    setErr("");
    setCancelResult(null);
    try {
      const res = await axiosInstance.post(API_PATHS.BILLING.CANCEL, {
        at_period_end: atPeriodEnd,
      });
      setCancelResult(res.data);
      await load();
    } catch (e) {
      setErr(
        e?.response?.data?.detail ||
          e?.response?.data?.message ||
          e?.message ||
          "Cancellation failed"
      );
    } finally {
      setBusy(false);
    }
  };

  const fmtDate = (iso) => {
    try {
      return new Date(iso).toLocaleString();
    } catch {
      return String(iso || "");
    }
  };

  const nextRenewal =
    me?.period_end
      ? new Date(me.period_end).toLocaleDateString()
      : me?.current_period_end
      ? new Date(me.current_period_end).toLocaleDateString()
      : null;

  const isPaid = currentPlan !== "free";

  return (
    <DashboardLayout activeMenu="Billing">
      <div className="m-3 mx-auto max-w-5xl space-y-6">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-2xl md:text-3xl font-semibold">Manage Subscription</h1>
            <p className="text-sm text-gray-500 mt-1">
              View your current plan, usage, upgrade, or cancel your subscription.
            </p>
          </div>
          <button
            onClick={load}
            disabled={loading}
            className="inline-flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-60"
            title="Refresh"
          >
            <LuRefreshCw className={loading ? "animate-spin" : ""} />
            Refresh
          </button>
        </div>

        {err && (
          <div className="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
            {err}
          </div>
        )}

        {/* Current plan & actions */}
        <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <div className="flex flex-wrap items-start justify-between gap-4">
            <div>
              <div className="flex items-center gap-2">
                <PlanBadge name={currentPlan} />
                {me?.status && (
                  <span className="rounded-full bg-emerald-50 px-2 py-0.5 text-[11px] font-semibold uppercase tracking-wide text-emerald-700">
                    {me.status}
                  </span>
                )}
              </div>
              <div className="mt-2 text-xl font-semibold flex items-center gap-2">
                <LuCrown className="text-indigo-600" />
                {currentPlan === "free"
                  ? "Free"
                  : currentPlan === "basic"
                  ? "Basic"
                  : "Premium"}
              </div>
              <div className="text-sm text-gray-600 mt-1">
                {nextRenewal ? (
                  <>
                    Next renewal: <span className="font-medium">{nextRenewal}</span>
                  </>
                ) : (
                  <>No renewal date for free plan</>
                )}
              </div>
            </div>

            <div className="flex flex-col sm:flex-row sm:items-center gap-2">
              {currentPlan !== "premium" && (
                <button
                  onClick={() => startCheckout("premium")}
                  disabled={busy}
                  className="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
                >
                  <LuArrowRightLeft />
                  Upgrade to Premium
                </button>
              )}
              {currentPlan === "free" && (
                <button
                  onClick={() => startCheckout("basic")}
                  disabled={busy}
                  className="inline-flex items-center gap-2 rounded-lg border border-indigo-600 bg-white px-4 py-2 text-sm font-medium text-indigo-700 hover:bg-indigo-50 disabled:opacity-60"
                >
                  <LuArrowRightLeft />
                  Upgrade to Basic
                </button>
              )}

              {/* Cancel subscription (no portal) */}
              {isPaid && (
                <div className="flex items-center gap-2">
                  <button
                    onClick={cancelSubscription}
                    disabled={busy}
                    className="inline-flex items-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-60"
                    title={
                      atPeriodEnd
                        ? "Will stay active until the end of the period"
                        : "Cancel immediately"
                    }
                  >
                    {atPeriodEnd ? <LuClock4 /> : <LuCircle />}
                    {busy ? "Cancelling…" : atPeriodEnd ? "Cancel at period end" : "Cancel now"}
                  </button>
                  <label className="flex items-center gap-2 text-xs text-gray-600">
                    <input
                      type="checkbox"
                      checked={atPeriodEnd}
                      onChange={(e) => setAtPeriodEnd(e.target.checked)}
                    />
                    cancel at period end
                  </label>
                </div>
              )}
            </div>
          </div>

          {/* Feature list for current plan */}
          <div className="mt-4 rounded-lg border border-gray-100 bg-gray-50 p-4">
            <div className="text-xs font-semibold uppercase tracking-wide text-gray-500 mb-2">
              Plan Includes
            </div>
            <ul className="grid sm:grid-cols-2 gap-2 text-sm text-gray-700">
              {(planMeta[currentPlan]?.features || []).map((f, i) => (
                <li key={i} className="flex items-center gap-2">
                  <LuCircleCheckBig className="text-emerald-600" />
                  <span>{f}</span>
                </li>
              ))}
            </ul>
          </div>

          {/* Cancellation result notice */}
          {cancelResult && (
            <div className="mt-3 rounded-md bg-gray-50 px-3 py-2 text-sm text-gray-700">
              {cancelResult.status === "scheduled_cancellation" ? (
                <>
                  Cancellation scheduled for{" "}
                  <strong>{fmtDate(cancelResult.cancel_at)}</strong>. You’ll keep access until the end of the period.
                </>
              ) : cancelResult.status === "canceled" ? (
                <>Subscription cancelled. You’re now on the <strong>Free</strong> plan.</>
              ) : (
                <>No active subscription to cancel.</>
              )}
            </div>
          )}
        </div>

        {/* Usage */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <div className="text-sm font-semibold text-gray-800 mb-3">Query Usage</div>
            <Progress
              label="Engine + Scientific queries (this period)"
              used={me?.usage?.queries_used ?? me?.usage?.queries_month}
              limit={me?.limits?.queries_limit ?? me?.limits?.queries_month}
            />
            {me?.usage?.queries_reset_at && (
              <div className="mt-2 text-xs text-gray-500">
                Resets on {new Date(me.usage.queries_reset_at).toLocaleDateString()}
              </div>
            )}
          </div>

          <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
            <div className="text-sm font-semibold text-gray-800 mb-3">
              Uploads & Storage
            </div>
            <Progress
              label="Uploads (count)"
              used={me?.usage?.uploads_count}
              limit={me?.limits?.uploads_count}
            />
            <div className="mt-3" />
            <ByteProgress
              label="Data uploaded (this period)"
              used={me?.usage?.upload_bytes_used ?? me?.usage?.upload_bytes_month}
              limit={me?.limits?.upload_bytes_limit ?? me?.limits?.upload_bytes_month}
            />
          </div>
        </div>

        {/* Plans overview */}
        <div className="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
          <div className="flex items-center justify-between">
            <div className="text-sm font-semibold text-gray-800">Plans</div>
            <div className="text-xs text-gray-500">
              Change or cancel anytime.
            </div>
          </div>

          <div className="mt-4 grid grid-cols-1 md:grid-cols-3 gap-6">
            {["free", "basic", "premium"].map((p) => {
              const meta = planMeta[p];
              const price = meta?.price || "";
              const isCurrent = currentPlan === p;
              const isPaidPlan = p !== "free";
              return (
                <div
                  key={p}
                  className={`rounded-xl border p-5 ${
                    p === "premium" ? "border-indigo-500 shadow" : "border-gray-200 shadow-sm"
                  } bg-white`}
                >
                  <div className="flex items-center justify-between">
                    <div className="text-lg font-medium capitalize">{p}</div>
                    {isCurrent && <PlanBadge name="current" />}
                  </div>
                  <div className="text-2xl font-semibold mt-1">{price}</div>
                  <ul className="mt-3 space-y-1 text-sm text-gray-700">
                    {(meta?.features || []).map((f, i) => (
                      <li key={i} className="flex items-center gap-2">
                        <LuCircleCheckBig className="text-emerald-600" />
                        <span>{f}</span>
                      </li>
                    ))}
                  </ul>
                  <div className="mt-4">
                    {!isPaidPlan ? (
                      <button
                        disabled
                        className="w-full rounded-lg border border-gray-200 bg-gray-50 px-4 py-2 text-sm font-medium text-gray-500"
                      >
                        Included
                      </button>
                    ) : isCurrent ? (
                      <div className="flex flex-col gap-2">
                        <button
                          onClick={() => setAtPeriodEnd(true)}
                          className="w-full rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700"
                          disabled
                          title="Toggle below to choose immediate cancellation"
                        >
                          Current plan
                        </button>
                        <button
                          onClick={cancelSubscription}
                          disabled={busy}
                          className="w-full inline-flex items-center justify-center gap-2 rounded-lg border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-60"
                        >
                          {atPeriodEnd ? <LuClock4 /> : <LuXCircle />}
                          {busy ? "Cancelling…" : atPeriodEnd ? "Cancel at period end" : "Cancel now"}
                        </button>
                        <label className="flex items-center gap-2 text-xs text-gray-600">
                          <input
                            type="checkbox"
                            checked={atPeriodEnd}
                            onChange={(e) => setAtPeriodEnd(e.target.checked)}
                          />
                          cancel at period end
                        </label>
                      </div>
                    ) : (
                      <button
                        onClick={() => startCheckout(p)}
                        disabled={busy}
                        className="w-full rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500 disabled:opacity-60"
                      >
                        Choose {p.charAt(0).toUpperCase() + p.slice(1)}
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </DashboardLayout>
  );
};

export default ManageSubscription;