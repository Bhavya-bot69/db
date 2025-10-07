import React, { createContext, useState, useEffect, useContext, useCallback } from "react";

export const AppContext = createContext();

export const AppProvider = ({ children }) => {
  const [user, setUser] = useState(null); // { role, username }
  const [events, setEvents] = useState([]);
  const [teams, setTeams] = useState([]);
  const [judges, setJudges] = useState([]);
  const [categories, setCategories] = useState([]);
  const [evaluations, setEvaluations] = useState([]);
  const [loading, setLoading] = useState(true);

  // Load data from localStorage
  const loadData = useCallback(() => {
    setEvents(
      JSON.parse(localStorage.getItem("events")) || [
        { id: 1, name: "Event 1", description: "First event" },
      ]
    );
    setTeams(
      JSON.parse(localStorage.getItem("teams")) || [
        { id: 1, name: "Team A", description: "Team Alpha" },
        { id: 2, name: "Team B", description: "Team Beta" },
      ]
    );
    setJudges(
      JSON.parse(localStorage.getItem("judges")) || [
        { id: 1, name: "Judge 1", description: "First judge" },
      ]
    );
    setCategories(
      JSON.parse(localStorage.getItem("categories")) || [
        { id: 1, name: "Idea", weight: 1 },
        { id: 2, name: "Presentation", weight: 1 },
        { id: 3, name: "Execution", weight: 1 },
      ]
    );
    setEvaluations(JSON.parse(localStorage.getItem("evaluations")) || []);
  }, []);

  // Save data to localStorage (memoized so ESLint is happy)
  const saveData = useCallback(() => {
    localStorage.setItem("events", JSON.stringify(events));
    localStorage.setItem("teams", JSON.stringify(teams));
    localStorage.setItem("judges", JSON.stringify(judges));
    localStorage.setItem("categories", JSON.stringify(categories));
    localStorage.setItem("evaluations", JSON.stringify(evaluations));
  }, [events, teams, judges, categories, evaluations]);

  // Login function
  const login = (userData) => {
    setUser({
      role: "admin",
      username: userData.name,
      email: userData.email,
      id: userData.id,
    });
  };

  // Logout
  const logout = () => {
    setUser(null);
    localStorage.removeItem("currentUser");
    localStorage.removeItem("token");
    localStorage.removeItem("user");
  };

  // Verify token and load user on mount
  useEffect(() => {
    const verifyToken = async () => {
      const token = localStorage.getItem("token");
      const currentUser = localStorage.getItem("currentUser");

      if (token && currentUser) {
        try {
          const res = await fetch("http://localhost:5000/api/auth/me", {
            headers: {
              Authorization: `Bearer ${token}`,
            },
          });

          if (res.ok) {
            const userData = JSON.parse(currentUser);
            setUser({
              role: "admin",
              username: userData.name,
              email: userData.email,
              id: userData.id,
            });
          } else {
            // Token is invalid, clear it
            localStorage.removeItem("token");
            localStorage.removeItem("currentUser");
          }
        } catch (error) {
          console.error("Token verification failed:", error);
          localStorage.removeItem("token");
          localStorage.removeItem("currentUser");
        }
      }

      setLoading(false);
    };

    verifyToken();
    loadData();
  }, [loadData]);

  // Save data when state changes
  useEffect(() => {
    saveData();
  }, [saveData]);

  return (
    <AppContext.Provider
      value={{
        user,
        events,
        teams,
        judges,
        categories,
        evaluations,
        loading,
        login,
        logout,
        setEvents,
        setTeams,
        setJudges,
        setCategories,
        setEvaluations,
      }}
    >
      {children}
    </AppContext.Provider>
  );
};

export const useApp = () => useContext(AppContext);
