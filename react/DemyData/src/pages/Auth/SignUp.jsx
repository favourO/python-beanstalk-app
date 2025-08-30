// src/pages/auth/SignUp.jsx
import React, { useContext, useState } from "react";
import AuthLayout from "../../components/layouts/AuthLayout";
import { validateEmail } from "../../utils/helper";
import Input from "../../components/Inputs/Input";
import { Link, useNavigate } from "react-router-dom";
import axiosInstance from "../../utils/axiosInstance";
import { API_PATHS } from "../../utils/apiPaths";
import { UserContext } from "../../context/userContext";
import INSIGHTS_CLIPART from "../../assets/illustrations/upload-insights.png";

const COUNTRIES = [
  { label: "United Kingdom", value: "GB" },
  { label: "United States", value: "US" },
  { label: "Canada", value: "CA" },
  { label: "Germany", value: "DE" },
  { label: "France", value: "FR" },
  { label: "Netherlands", value: "NL" },
  { label: "Spain", value: "ES" },
  { label: "Italy", value: "IT" },
  { label: "Nigeria", value: "NG" },
  { label: "Kenya", value: "KE" },
  { label: "India", value: "IN" },
  { label: "Singapore", value: "SG" },
  { label: "Australia", value: "AU" },
  { label: "Other", value: "ZZ" },
];

const SignUp = () => {
  const [firstName, setFirstName]   = useState("");
  const [lastName, setLastName]     = useState("");
  const [country, setCountry]       = useState("GB");
  const [email, setEmail]           = useState("");
  const [password, setPassword]     = useState("");
  const [error, setError]           = useState(null);
  const [submitting, setSubmitting] = useState(false);

  const { updateUser } = useContext(UserContext);
  const navigate = useNavigate();

  const handleSignUp = async (e) => {
    e.preventDefault();

    if (!firstName.trim() || !lastName.trim()) return setError("Please enter your first and last name.");
    if (!country) return setError("Please select your country.");
    if (!validateEmail(email)) return setError("Please enter a valid email address.");
    if (!password || password.length < 8) return setError("Password must be at least 8 characters.");

    setError("");
    setSubmitting(true);

    try {
      // Backend expects snake_case + ISO code
      const payload = {
        email: email.trim(),
        password,
        first_name: firstName.trim(),
        last_name: lastName.trim(),
        country, // "GB"
      };

      const { data } = await axiosInstance.post(API_PATHS.AUTH.SIGNUP, payload);

      // You get: { user, message }
      // Stash email to help the verify page
      localStorage.setItem("pendingEmail", email.trim());
      // (Optional) light user shell
      updateUser(data?.user || { firstName, lastName, email, country });

      // Go to verify page with email in query string
      navigate(`/verify?email=${encodeURIComponent(email.trim())}`);
    } catch (err) {
      setError(err?.response?.data?.message || err.message || "Something went wrong. Please try again.");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AuthLayout illustrationSrc={INSIGHTS_CLIPART} illustrationAlt="Data upload to insights">
      <div className="lg:w-[100%] h-auto md:h-full mt-10 md:mt-0 flex flex-col justify-center">
        <div className="mb-6">
          <h3 className="text-2xl font-semibold text-gray-900">Create your account</h3>
          <p className="text-sm text-gray-500 mt-1">
            Start turning your data uploads into insights in minutes.
          </p>
        </div>

        <form onSubmit={handleSignUp} className="card max-w-2xl p-6 border border-gray-200 rounded-2xl bg-white shadow-sm">
          <div className="grid grid-cols-1 gap-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <Input
                value={firstName}
                onChange={({ target }) => setFirstName(target.value)}
                label="First name"
                placeholder="Ada"
                type="text"
              />
              <Input
                value={lastName}
                onChange={({ target }) => setLastName(target.value)}
                label="Last name"
                placeholder="Lovelace"
                type="text"
              />
            </div>

            {/* Country spans full width */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="md:col-span-2">
                <label className="block text-xs font-medium text-gray-700 mb-1">Country</label>
                <select
                  value={country}
                  onChange={(e) => setCountry(e.target.value)}
                  className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-indigo-500"
                >
                  {COUNTRIES.map((c) => (
                    <option key={c.value} value={c.value}>{c.label}</option>
                  ))}
                </select>
              </div>
            </div>

            <Input
              value={email}
              onChange={({ target }) => setEmail(target.value)}
              label="Work email"
              placeholder="you@company.com"
              type="email"
            />

            <Input
              value={password}
              onChange={({ target }) => setPassword(target.value)}
              label="Password"
              placeholder="Min 8 characters"
              type="password"
            />

            {error && <p className="text-red-600 text-xs">{error}</p>}

            <button
              type="submit"
              disabled={submitting}
              className="btn-primary w-full md:w-auto"
            >
              {submitting ? "Creating account…" : "Create account"}
            </button>

            <p className="text-[13px] text-slate-700 mt-3">
              Already have an account?{" "}
              <Link className="font-medium text-primary underline" to="/login">
                Log in
              </Link>
            </p>
          </div>
        </form>

        <p className="text-[11px] text-gray-400 mt-4">
          By creating an account, you agree to our Terms and Privacy Policy.
        </p>
      </div>
    </AuthLayout>
  );
};

export default SignUp;