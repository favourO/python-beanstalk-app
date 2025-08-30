// src/pages/billing/BillingSuccess.jsx
import React, { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import DashboardLayout from "../../components/layouts/DashboardLayout";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";

const BillingSuccess = () => {
  const navigate = useNavigate();

  useEffect(() => {
    // refresh local subscription cache then send user back to files
    (async () => {
      try { await axiosInstance.get(API_PATHS.BILLING.ME); } catch {}
      setTimeout(() => navigate("/admin/files"), 1200);
    })();
  }, [navigate]);

  return (
    <DashboardLayout activeMenu="Billing">
      <div className="m-3 max-w-xl mx-auto rounded-lg border border-green-200 bg-green-50 p-4 text-green-800">
        <div className="text-lg font-semibold">Payment successful 🎉</div>
        <p className="text-sm mt-1">
          Your subscription is active. Redirecting you to your files…
        </p>
      </div>
    </DashboardLayout>
  );
};
export default BillingSuccess;