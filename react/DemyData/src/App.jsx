import React, { useContext } from "react";
import { BrowserRouter as Router, Routes, Route, Outlet, Navigate } from "react-router-dom";
import Dashboard from "./pages/Admin/Dashboard";
import Login from "./pages/Auth/Login";
import SignUp from "./pages/Auth/SignUp";
import Verify from "./pages/auth/Verify";
import Insights from "./pages/Insights/Insights";

import FilesAndAssets from "./pages/Admin/FilesAndAssets";
import ViewFile from "./pages/Admin/ViewFile";
import ConnectedSources from "./pages/Admin/ConnectedSources";

import Premium from "./pages/billing/Premium";
import Billing from "./pages/billing/Billing";
import BillingSuccess from "./pages/billing/BillingSuccess";
import ManageSubscription from "./pages/Billing/ManageSubscription";

import PrivateRoute from "./routes/PrivateRoute";
import UserProvider, { UserContext } from "./context/userContext";
import { Toaster } from "react-hot-toast";


const App = () => {
  return (
    <UserProvider>
      <div>
        <Router>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/signUp" element={<SignUp />} />
            <Route path="/verify" element={<Verify />} />

            {/* Admin Routes */}
            <Route element={<PrivateRoute allowedRoles={["admin"]} />}>
              <Route path="/admin/dashboard" element={<Dashboard />} />
              <Route path="/admin/files" element={<FilesAndAssets />} />
              <Route path="/admin/files/:uploadId" element={<ViewFile />} />
              <Route path="/admin/connected-sources" element={<ConnectedSources />} />
              <Route path="/admin/insights" element={<Insights />} />
              <Route path="/billing/manage" element={<ManageSubscription />} />
              <Route path="/premium" element={<Premium />} />
              <Route path="/billing" element={<Billing />} />
              <Route path="/billing/success" element={<BillingSuccess />} />
            </Route>

             {/* Default Route */}
            <Route path="/" element={<Root />} />
          </Routes>
        </Router>
      </div>

      <Toaster
        toastOptions={{
          className: "",
          style: {
            fontSize: "13px",
          },
        }}
      />
    </UserProvider>
  );
};

export default App;

const Root = () => {
  const { user, loading } = useContext(UserContext);

  if(loading) return <Outlet />
  
  if (!user) {
    return <Navigate to="/login" />;
  }

  return <Navigate to="/admin/dashboard" />;
};