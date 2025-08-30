import React from "react";
import PropTypes from "prop-types";
import DEFAULT_IMG from "../../assets/images/auth-img.jpg"; // replace with your new AI-themed hero image

const AuthLayout = ({
  children,
  illustrationSrc = DEFAULT_IMG,
  illustrationAlt = "AI Data Management & Insights illustration",
}) => {
  return (
    <div className="min-h-screen grid grid-cols-1 lg:grid-cols-2 bg-slate-200">
      {/* Form column */}
      <div className="flex items-center justify-center p-6 sm:p-10">
        <div className="w-full max-w-md">
          {/* Brand */}
          <div className="mb-6 sm:mb-8">
            <div className="flex items-center gap-2">
              <div className="h-9 w-9 rounded-xl bg-primary/10 flex items-center justify-center">
                <span className="text-primary font-bold">Δ</span>
              </div>
              <span className="text-xl font-semibold text-slate-900">
                Demy Data
              </span>
            </div>
          </div>

          {/* Card */}
          <div className="rounded-2xl bg-white shadow-xl ring-1 ring-black/5 p-6 sm:p-8">
            {children}
          </div>

          <p className="mt-6 text-center text-xs text-slate-500">
            © {new Date().getFullYear()} Demy Data. All rights reserved.
          </p>
        </div>
      </div>

      {/* Visual / marketing column */}
      <div className="relative hidden lg:block">
        <div className="absolute inset-0 bg-gradient-to-br via-white" />
        <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgba(255,255,255,0.15),transparent_60%)]" />
        <div className="relative h-full w-full flex items-center justify-center p-10">
          <img
            src={illustrationSrc}
            alt={illustrationAlt}
            className="max-h-[70vh] w-auto drop-shadow-2xl rounded-xl"
          />
          <div className="absolute bottom-10 left-10 right-10 text-white/90">
            <h3 className="text-2xl font-semibold text-slate-500">
              Agent AI for Data Science
            </h3>
            <p className="mt-2 text-sm text-slate-500 leading-6">
              Ingest, govern, and visualize data. Auto-generate SQL and insights.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

AuthLayout.propTypes = {
  children: PropTypes.node.isRequired,
  illustrationSrc: PropTypes.string,
  illustrationAlt: PropTypes.string,
};

export default AuthLayout;
