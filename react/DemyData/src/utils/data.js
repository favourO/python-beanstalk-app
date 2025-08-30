import {
    LuLayoutDashboard,
    LuUsers,
    LuClipboardCheck,
    LuSquarePlus,
    LuLogOut,
    LuDatabaseBackup,
    LuMonitorCheck
  } from "react-icons/lu";
  
  
  export const SIDE_MENU_DATA = [
    {
      id: "01",
      label: "Databoard",
      icon: LuLayoutDashboard,
      path: "/admin/dashboard",
    },
    {
      id: "02",
      label: "Uploads",
      icon: LuClipboardCheck,
      path: "/admin/files",
    },
    {
      id: "03",
      label: "Connected Sources",
      icon: LuDatabaseBackup,
      path: "/admin/connected-sources",
    },
    {
      id: "04",
      label: "Insights",
      icon: LuSquarePlus,
      path: "/admin/insights",
    },
    {
      id: "05",
      label: "Team Members",
      icon: LuUsers,
      path: "/admin/users",
    },
    {
      id: "06",
      label: "Subscriptions",
      icon: LuMonitorCheck,
      path: "/billing/manage",
    },
    {
      id: "07",
      label: "Logout",
      icon: LuLogOut,
      path: "logout",
    },
  ];
  
  