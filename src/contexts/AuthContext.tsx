import { createContext, useContext, useState, ReactNode } from "react";

interface User {
  id: string;
  name: string;
  folderCount: number;
}

type MockUserEntry = { id: string; password: string; name: string; folderCount: number };

// Hardcoded mock users for the login page demo
const MOCK_USERS_DATA: MockUserEntry[] = [
  { id: "TNEEIN01", password: "4YOU", name: "TNEEIN01 TEST1", folderCount: 9 },
  { id: "TNEEMA01", password: "4YOU", name: "TNEEMA01 TEST2", folderCount: 5 },
];

const USERS: Record<string, { password: string; user: User }> = Object.fromEntries(
  MOCK_USERS_DATA.map(({ id, password, name, folderCount }) => [
    id.toUpperCase(),
    { password, user: { id, name, folderCount } },
  ])
);

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
