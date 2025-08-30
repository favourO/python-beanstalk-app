// src/context/userContext.jsx
import React, { createContext, useEffect, useMemo, useState } from "react";
import axiosInstance from "../utils/axiosInstance";

export const UserContext = createContext({
  user: null,
  loading: true,
  updateUser: () => {},
  clearUser: () => {},
});

export const UserProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem("token");
    const cached = localStorage.getItem("user");
    const finish = () => setLoading(false);

    if (!token) return finish();

    if (cached) {
      try { setUser(JSON.parse(cached)); } catch {}
      return finish();
    }

    axiosInstance
      .get("/auth/me")
      .then((res) => {
        if (res.data?.user) {
          setUser(res.data.user);
          localStorage.setItem("user", JSON.stringify(res.data.user));
        } else {
          localStorage.removeItem("token");
        }
      })
      .catch(() => {
        localStorage.removeItem("token");
        localStorage.removeItem("user");
      })
      .finally(finish);
  }, []);

  const updateUser = (u) => {
    setUser(u);
    localStorage.setItem("user", JSON.stringify(u));
  };

  const clearUser = () => {
    setUser(null);
    localStorage.removeItem("user");
    localStorage.removeItem("token");
  };

  const value = useMemo(() => ({ user, loading, updateUser, clearUser }), [user, loading]);
  return <UserContext.Provider value={value}>{children}</UserContext.Provider>;
};

// Optional: keep this if you want default imports elsewhere
export default UserProvider;
