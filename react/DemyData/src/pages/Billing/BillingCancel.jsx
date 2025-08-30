// src/pages/billing/BillingCancel.jsx
import React from "react";
import { Link } from "react-router-dom";
import DashboardLayout from "../../components/layouts/DashboardLayout";

const BillingCancel = () => {
  return (
    <DashboardLayout activeMenu="Billing">
      <div className="m-3 max-w-xl mx-auto rounded-lg border border-yellow-200 bg-yellow-50 p-4 text-yellow-800">
        <div className="text-lg font-semibold">Checkout canceled</div>
        <p className="text-sm mt-1">
          No charges were made. You can try again anytime.
        </p>
        <Link
          to="/billing/premium"
          className="inline-block mt-3 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-500"
        >
          Back to plans
        </Link>
      </div>
    </DashboardLayout>
  );
};
export default BillingCancel;