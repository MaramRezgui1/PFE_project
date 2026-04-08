import { createContext, useContext, useState, ReactNode } from "react";

interface User {
  id: string;
  name: string;
  folderCount: number;
}

type MockUserEntry = { id: string; password: string; name: string; folderCount: number };

const buildUsersMap = (): Record<string, { password: string; user: User }> => {
  const raw = import.meta.env.VITE_MOCK_USERS;
  if (!raw) {
    console.warn("VITE_MOCK_USERS is not defined. Copy .env.example to .env.local and fill in the values.");
    return {};
  }
  const entries: MockUserEntry[] = JSON.parse(raw);
  return Object.fromEntries(
    entries.map(({ id, password, name, folderCount }) => [
      id.toUpperCase(),
      { password, user: { id, name, folderCount } },
    ])
  );
};

const USERS = buildUsersMap();

interface AuthContextType {
  user: User | null;
  login: (identifier: string, password: string) => boolean;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | null>(null);

export const useAuth = () => {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
};

export const AuthProvider = ({ children }: { children: ReactNode }) => {
  const [user, setUser] = useState<User | null>(null);

  const login = (identifier: string, password: string) => {
    const entry = USERS[identifier.toUpperCase()];
    if (entry && entry.password === password) {
      setUser(entry.user);
      return true;
    }
    return false;
  };

  const logout = () => setUser(null);

  return (
    <AuthContext.Provider value={{ user, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
};
