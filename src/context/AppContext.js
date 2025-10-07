import React, { createContext, useState, useEffect, useContext, useCallback } from "react";
import { supabase } from "../config/supabase";

export const AppContext = createContext();

export const AppProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [events, setEvents] = useState([]);
  const [teams, setTeams] = useState([]);
  const [judges, setJudges] = useState([]);
  const [categories, setCategories] = useState([]);
  const [evaluations, setEvaluations] = useState([]);
  const [loading, setLoading] = useState(true);

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

  const saveData = useCallback(() => {
    localStorage.setItem("events", JSON.stringify(events));
    localStorage.setItem("teams", JSON.stringify(teams));
    localStorage.setItem("judges", JSON.stringify(judges));
    localStorage.setItem("categories", JSON.stringify(categories));
    localStorage.setItem("evaluations", JSON.stringify(evaluations));
  }, [events, teams, judges, categories, evaluations]);

  const login = (userData) => {
    setUser({
      role: "admin",
      username: userData.name,
      email: userData.email,
      id: userData.id,
    });
  };

  const logout = async () => {
    await supabase.auth.signOut();
    setUser(null);
    localStorage.removeItem("currentUser");
  };

  useEffect(() => {
    const initAuth = async () => {
      const { data: { session } } = await supabase.auth.getSession();

      if (session?.user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', session.user.id)
          .maybeSingle();

        if (profile) {
          setUser({
            role: "admin",
            username: profile.name,
            email: profile.email,
            id: profile.id,
          });
        }
      }

      setLoading(false);
    };

    initAuth();
    loadData();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (event, session) => {
        (async () => {
          if (event === 'SIGNED_IN' && session?.user) {
            const { data: profile } = await supabase
              .from('profiles')
              .select('*')
              .eq('id', session.user.id)
              .maybeSingle();

            if (profile) {
              setUser({
                role: "admin",
                username: profile.name,
                email: profile.email,
                id: profile.id,
              });
            }
          } else if (event === 'SIGNED_OUT') {
            setUser(null);
          }
        })();
      }
    );

    return () => {
      subscription.unsubscribe();
    };
  }, [loadData]);

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
