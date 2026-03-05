import { useAuth } from "@/contexts/AuthContext";
import { useNavigate } from "react-router-dom";
import { Search, HelpCircle, Power, Menu, FolderOpen, ChevronDown, ArrowRight, CheckCircle } from "lucide-react";
import { Input } from "@/components/ui/input";

const Dashboard = () => {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  const handleLogout = () => {
    logout();
    navigate("/");
  };

  if (!user) {
    navigate("/");
    return null;
  }

  return (
    <div className="min-h-screen bg-[hsl(0,0%,95%)]">
      {/* Top Navbar */}
      <header className="bg-[hsl(0,0%,20%)] h-12 flex items-center justify-between px-4 text-white">
        <div className="flex items-center gap-3">
          <button className="hover:opacity-80"><Menu className="h-5 w-5" /></button>
          <div className="flex items-center justify-center w-9 h-9 rounded-full border-2 border-[hsl(270,70%,50%)]">
            <span className="text-xs font-bold">4YOU</span>
          </div>
        </div>
        <div className="flex items-center gap-4">
          <button className="hover:opacity-80"><Search className="h-5 w-5" /></button>
          <button className="hover:opacity-80"><HelpCircle className="h-5 w-5" /></button>
          <button onClick={handleLogout} className="hover:opacity-80"><Power className="h-5 w-5" /></button>
        </div>
      </header>

      {/* Hero Banner */}
      <div className="relative h-56 overflow-hidden">
        <div
          className="absolute inset-0"
          style={{
            background: "linear-gradient(135deg, hsl(270 60% 30%) 0%, hsl(290 50% 40%) 40%, hsl(320 60% 50% / 0.8) 100%)",
          }}
        />
        {/* User info - right side */}
        <div className="absolute right-12 top-1/2 -translate-y-1/2 flex flex-col items-center gap-2">
          <div className="w-20 h-20 rounded-full border-4 border-[hsl(270,70%,50%)] bg-[hsl(0,0%,80%)] flex items-center justify-center">
            <span className="text-2xl text-[hsl(0,0%,50%)]">👤</span>
          </div>
          <h2 className="text-white font-semibold text-lg">{user.name}</h2>
          <div className="flex items-center gap-1 text-white">
            <span>{user.folderCount}</span>
            <FolderOpen className="h-4 w-4" />
          </div>
        </div>
        {/* Arrow navigation */}
        <button className="absolute right-4 top-1/2 -translate-y-1/2 w-10 h-10 rounded-full border-2 border-white flex items-center justify-center text-white hover:bg-white/10">
          <ArrowRight className="h-5 w-5" />
        </button>
      </div>

      {/* Content Area */}
      <div className="flex gap-0 -mt-4 relative z-10 px-4">
        {/* Left Section - Cards */}
        <div className="flex-1 flex gap-4">
          {/* Tasks Card */}
          <div className="bg-[hsl(195,60%,95%)] rounded-md p-6 flex-1 flex items-center justify-center">
            <p className="text-[hsl(195,60%,35%)] text-sm text-center">
              Vous n'avez actuellement aucune tâche à traiter.
            </p>
          </div>

          {/* Congés Card */}
          <div className="bg-[hsl(270,60%,30%)] rounded-md p-6 text-white text-center min-w-[200px]">
            <p className="text-sm mb-3">Mon solde de congés</p>
            <div className="text-4xl font-bold">18<span className="text-lg font-normal">j</span></div>
            <div className="border-t border-white/30 my-2" />
            <div className="text-2xl font-bold">18<span className="text-lg font-normal">j</span></div>
          </div>

          {/* Absences Card */}
          <div className="bg-[hsl(270,60%,30%)] rounded-md p-6 text-white text-center min-w-[200px]">
            <p className="text-sm mb-3">Mes autres absences</p>
            <div className="text-4xl font-bold">0<span className="text-lg font-normal">j pris</span></div>
          </div>
        </div>

        {/* Right Sidebar - Démarches */}
        <div className="w-[380px] ml-4 bg-white rounded-md shadow-sm p-4">
          <Input
            placeholder="Rechercher"
            className="mb-4 border-[hsl(0,0%,80%)]"
          />

          <div className="space-y-4">
            <DemarcheItem
              icon="💼"
              title="Ma demande d'acompte ou d'avance"
              validated={5}
              refused={4}
            />
            <DemarcheItem
              icon="👨‍👩‍👧"
              title="Mon changement de composition familiale"
              validated={8}
              refused={2}
            />
            <DemarcheItem
              icon="💍"
              title="Mon changement de situation familiale"
              validated={1}
            />
            <DemarcheItem
              icon="❓"
              title="Mes questions RH"
            />
          </div>

          <div className="mt-4 flex items-center justify-end gap-1 text-[hsl(var(--link-color))] text-sm cursor-pointer hover:underline">
            <CheckCircle className="h-4 w-4" />
            Accéder à toutes mes démarches
          </div>

          <div className="flex justify-center mt-2">
            <ChevronDown className="h-5 w-5 text-[hsl(0,0%,60%)]" />
          </div>
        </div>
      </div>
    </div>
  );
};

const DemarcheItem = ({
  icon,
  title,
  validated,
  refused,
}: {
  icon: string;
  title: string;
  validated?: number;
  refused?: number;
}) => (
  <div className="flex items-center gap-3">
    <div className="w-10 h-10 rounded-full bg-[hsl(210,20%,90%)] flex items-center justify-center text-lg border-2 border-[hsl(270,50%,40%)]">
      {icon}
    </div>
    <div>
      <p className="text-sm font-medium text-[hsl(0,0%,20%)]">{title}</p>
      {(validated !== undefined || refused !== undefined) && (
        <p className="text-xs text-[hsl(0,0%,50%)]">
          {validated !== undefined && <span className="text-[hsl(150,60%,35%)]">{validated} validée{validated > 1 ? "s" : ""}</span>}
          {validated !== undefined && refused !== undefined && <span> | </span>}
          {refused !== undefined && <span className="text-[hsl(0,70%,50%)]">{refused} refusée{refused > 1 ? "s" : ""}</span>}
        </p>
      )}
    </div>
  </div>
);

export default Dashboard;
