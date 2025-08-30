// hooks/useUserAuth.js
import { useContext, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { UserContext } from "../context/userContext";

export const useUserAuth = () => {
  const { user, loading, clearUser } = useContext(UserContext);
  const navigate = useNavigate();

  useEffect(() => {
    if (loading) return; // wait for hydration
    const token = localStorage.getItem("token");

    if (user) return;            // already authenticated
    if (token) return;           // allow while user is being fetched elsewhere

    // truly unauthenticated
    clearUser();
    navigate("/login", { replace: true });
  }, [user, loading, clearUser, navigate]);
};
