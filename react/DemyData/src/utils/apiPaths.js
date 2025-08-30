export const BASE_URL = "http://localhost:8000/api";

// utils/apiPaths.js
export const API_PATHS = {
  AUTH: {
    SIGNUP: "/0.1.0/auth/signup",
    VERIFY: "/0.1.0/auth/verify",
    LOGIN: "/0.1.0/auth/login",
    GET_PROFILE: "/0.1.0/auth/me",
  },

  UPLOADS: {
    LIST: "/0.1.0/uploads",
    UPLOAD: "/0.1.0/uploads",
    MERGE: "/0.1.0/uploads/merge",
    DETAIL: (id) => `/0.1.0/uploads/${id}`,
    DELETE: (id) => `/0.1.0/uploads/${id}`,
    ROWS: (id, offset = 0, limit = 100) =>
      `/0.1.0/uploads/${id}/rows?offset=${offset}&limit=${limit}`,
  },

  ENGINE: {
    // generic (auto)
    QUERY: "/0.1.0/engine/query",

    // NEW: explicit by type
    QUERY_ANALYSIS: "/0.1.0/engine/query/analysis",
    QUERY_FPA: "/0.1.0/engine/query/fpa",
    QUERY_CHART: "/0.1.0/engine/query/chart",
    QUERY_TABLE: "/0.1.0/engine/query/table",

    // NEW: detailed report
    REPORT: "/0.1.0/engine/report",

    QUERIES: (uploadId, limit = 100, offset = 0) =>
      `/0.1.0/engine/queries?upload_id=${encodeURIComponent(
        uploadId
    )}&limit=${limit}&offset=${offset}`,

      // --- Scientific Analysis ---
    SCI_ANALYZE: "/0.1.0/engine/scientific-analysis",        // POST
    SCI_GET: (id) => `/0.1.0/engine/scientific-analysis/${id}`, // GET one
    SCI_LIST: "/0.1.0/engine/scientific-analyses",   
  },

  CONNECTED_DATA: {
    BASE: "/0.1.0/connected-data",
    LIST: "/0.1.0/connected-data",
    CREATE: "/0.1.0/connected-data",
    QUERY: (id) => `/0.1.0/connected-data/${id}/query`,
  },

  BILLING: {
    PLANS: "/0.1.0/billing/plans",
    ME: "/0.1.0/billing/me",
    CREATE_CHECKOUT: "/0.1.0/billing/create-checkout-session",
    CUSTOMER_PORTAL: "/0.1.0/billing/customer-portal",
    SUBSCRIBE_BASIC: "/0.1.0/billing/subscribe/basic",     
    SUBSCRIBE_PREMIUM: "/0.1.0/billing/subscribe/premium", 
    CANCEL: "/0.1.0/billing/cancel",
  },
};
