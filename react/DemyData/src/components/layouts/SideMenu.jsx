// file: src/components/navigation/SideMenu.jsx
import React, { useContext, useEffect, useState, useCallback } from "react";
import { SIDE_MENU_DATA } from "../../utils/data";
import { UserContext } from "../../context/userContext";
import { useNavigate } from "react-router-dom";
import { LuChevronLeft, LuChevronRight } from "react-icons/lu";

const SideMenu = ({ activeMenu }) => {
  const { user, clearUser } = useContext(UserContext);
  const [sideMenuData, setSideMenuData] = useState([]);
  const [collapsed, setCollapsed] = useState(false);

  const navigate = useNavigate();

  const handleClick = (route) => {
    if (route === "logout") {
      handelLogout();
      return;
    }
    navigate(route);
  };

  const handelLogout = () => {
    localStorage.clear();
    clearUser();
    navigate("/login");
  };

  // Load persisted collapsed state (optional)
  useEffect(() => {
    const saved = localStorage.getItem("sideMenuCollapsed");
    if (saved === "1") setCollapsed(true);
  }, []);

  // Persist collapsed state (optional)
  useEffect(() => {
    localStorage.setItem("sideMenuCollapsed", collapsed ? "1" : "0");
  }, [collapsed]);

  useEffect(() => {
    if (user) setSideMenuData(SIDE_MENU_DATA);
    return () => {};
  }, [user]);

  const toggleCollapsed = useCallback(() => {
    setCollapsed((c) => !c);
  }, []);

  return (
    <div
      className={`${collapsed ? "w-16" : "w-64"} h-[calc(100vh-61px)] bg-white border-r border-gray-200/50 sticky top-[61px] z-20 transition-[width] duration-200 ease-in-out`}
    >
      {/* Collapse/Expand toggle */}
      <div className="flex items-center justify-end px-2 py-2 border-b border-gray-200/60">
        <button
          onClick={toggleCollapsed}
          className="inline-flex items-center justify-center rounded-md border border-gray-200 bg-white p-1.5 text-gray-700 hover:bg-gray-50"
          title={collapsed ? "Expand menu" : "Collapse menu"}
          aria-label={collapsed ? "Expand menu" : "Collapse menu"}
        >
          {collapsed ? <LuChevronRight /> : <LuChevronLeft />}
        </button>
      </div>

      {/* Menu items */}
      <div className="py-2">
        {sideMenuData.map((item, index) => {
          const isActive = activeMenu === item.label;
          return (
            <button
              key={`menu_${index}`}
              className={`w-full flex items-center ${
                collapsed ? "justify-center gap-0 px-0" : "gap-4 px-6"
              } text-[15px] ${
                isActive
                  ? "text-primary bg-linear-to-r from-blue-50/40 to-blue-100/50 border-r-3"
                  : "text-gray-700"
              } py-3 mb-3 cursor-pointer hover:bg-gray-50 transition-colors`}
              onClick={() => handleClick(item.path)}
              title={collapsed ? item.label : undefined}
              aria-label={item.label}
            >
              <item.icon className="text-xl shrink-0" />
              {!collapsed && <span className="truncate">{item.label}</span>}
            </button>
          );
        })}
      </div>
    </div>
  );
};

export default SideMenu;