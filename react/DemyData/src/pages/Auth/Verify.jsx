// src/pages/auth/Verify.jsx
import React, { useEffect, useState, useContext } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import AuthLayout from "../../components/layouts/AuthLayout";
import Input from "../../components/Inputs/Input";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";
import { UserContext } from "../../context/userContext";
import INSIGHTS_CLIPART from "../../assets/illustrations/upload-insights.png";

const Verify = () => {
  const [search] = useSearchParams();
  const navigate = useNavigate();
  const { updateUser } = useContext(UserContext);

  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const fromQS = search.get("email");
    const fromLS = localStorage.getItem("pendingEmail") || "";
    setEmail(fromQS || fromLS || "");
  }, [search]);

  const submit = async (e) => {
    e.preventDefault();
    if (!email) return setError("Email is required.");
    if (!code || code.trim().length < 6) return setError("Enter the 6-digit code.");

    setError("");
    setSubmitting(true);

    try {
      const payload = { email: email.trim(), code: code.trim() };
      const { data } = await axiosInstance.post(API_PATHS.AUTH.VERIFY, payload);

      // Response: { user, access_token, token_type, expires_in }
      if (data?.access_token) {
        localStorage.setItem("token", data.access_token);
      }
      if (data?.user) {
        // Normalize names if needed for your UI
        updateUser({
          id: data.user.id,
          email: data.user.email,
          firstName: data.user.first_name,
          lastName: data.user.last_name,
          country: data.user.country,
          isVerified: data.user.is_verified,
        });
      }

      localStorage.removeItem("pendingEmail");
      navigate("/premium");
      // navigate("/admin/dashboard");
    } catch (err) {
      setError(err?.response?.data?.message || err.message || "Verification failed.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AuthLayout illustrationSrc={INSIGHTS_CLIPART} illustrationAlt="Verify your account">
      <div className="lg:w-[100%] h-auto md:h-full mt-10 md:mt-0 flex flex-col justify-center">
        <div className="mb-6">
          <h3 className="text-2xl font-semibold text-gray-900">Verify your email</h3>
          <p className="text-sm text-gray-500 mt-1">
            We sent a 6-digit login code to <span className="font-medium text-gray-700">{email || "your email"}</span>.
          </p>
        </div>

        <form onSubmit={submit} className="card max-w-md p-6 border border-gray-200 rounded-2xl bg-white shadow-sm">
          <div className="grid grid-cols-1 gap-4">
            <Input
              value={email}
              onChange={({ target }) => setEmail(target.value)}
              label="Email"
              placeholder="you@company.com"
              type="email"
            />
            <Input
              value={code}
              onChange={({ target }) => setCode(target.value.replace(/\s+/g, ""))}
              label="6-digit code"
              placeholder="000000"
              type="text"
              maxLength={6}
            />

            {error && <p className="text-red-600 text-xs">{error}</p>}

            <button
              type="submit"
              disabled={submitting}
              className="btn-primary w-full md:w-auto"
            >
              {submitting ? "Verifying…" : "Verify & continue"}
            </button>
          </div>
        </form>
      </div>
    </AuthLayout>
  );
};

export default Verify;