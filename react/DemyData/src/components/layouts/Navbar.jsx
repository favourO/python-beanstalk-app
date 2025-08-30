import React, { useState, useContext } from "react";
import { HiOutlineMenu, HiOutlineX, HiOutlineSearch } from "react-icons/hi";
import SideMenu from "./SideMenu";
import { UserContext } from "../../context/userContext";

const Navbar = ({ activeMenu, onSearch }) => {
  const [openSideMenu, setOpenSideMenu] = useState(false);
  const [mobileSearchOpen, setMobileSearchOpen] = useState(false);
  const [query, setQuery] = useState("");
  const { user } = useContext(UserContext);

  const firstName =
    (user?.first_name || user?.last_name)
      ? `${user.first_name ?? ""} ${user.last_name ?? ""}`.trim()
      : (typeof user?.name === "string" ? user.name.split(" ")[0] : "");

  const handleSubmit = (e) => {
    e.preventDefault();
    const q = query.trim();
    if (!q) return;
    onSearch ? onSearch(q) : console.log("Search:", q);
    setMobileSearchOpen(false);
  };

  return (
    <div className="grid grid-cols-3 items-center gap-3 bg-white dark:bg-gray-900 border border-b border-gray-200/50 dark:border-gray-800/60 backdrop-blur-[2px] py-4 px-7 sticky top-0 z-30">
      {/* Left: menu + brand */}
      <div className="flex items-center gap-3">
        <button
          className="block lg:hidden text-black dark:text-gray-100"
          onClick={() => setOpenSideMenu(!openSideMenu)}
          aria-label={openSideMenu ? "Close menu" : "Open menu"}
          aria-expanded={openSideMenu}
        >
          {openSideMenu ? (
            <HiOutlineX className="text-2xl" />
          ) : (
            <HiOutlineMenu className="text-2xl" />
          )}
        </button>

        <h2 className="text-lg font-medium text-black dark:text-white">
          Demy Data
        </h2>
      </div>

      <div className="col-start-3 justify-self-end">
        {firstName && (
          <span className="text-sm text-gray-700 dark:text-white">
            Hi, <span className="font-semibold">{firstName}</span>
          </span>
        )}
      </div>
      {/* Mobile search overlay */}
      {mobileSearchOpen && (
        <div className="fixed left-0 right-0 top-[61px] z-40 bg-white dark:bg-gray-900 border-y border-gray-200/50 dark:border-gray-800/60 px-4 py-3">
          <form onSubmit={handleSubmit}>
            <label htmlFor="mobile-site-search" className="sr-only">Search</label>
            <div className="relative">
              <HiOutlineSearch className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500" />
              <input
                id="mobile-site-search"
                type="search"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Search…"
                autoFocus
                className="w-full pl-10 pr-3 py-2 rounded-xl bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-sm text-gray-900 dark:text-gray-100 placeholder-gray-400 dark:placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent"
              />
            </div>
          </form>
        </div>
      )}

      {openSideMenu && (
        <div className="fixed top-[61px] -ml-4 bg-white dark:bg-gray-900 border border-gray-200/50 dark:border-gray-800/60">
          <SideMenu activeMenu={activeMenu} />
        </div>
      )}
    </div>
  );
};

export default Navbar;
