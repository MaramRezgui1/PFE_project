import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Eye, EyeOff, Lock } from "lucide-react";
import { SopraLogo } from "@/components/SopraLogo";
import { useAuth } from "@/contexts/AuthContext";
import { toast } from "@/hooks/use-toast";

export const LoginCard = () => {
  const [showPassword, setShowPassword] = useState(false);
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
  const [language, setLanguage] = useState("fr");
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const success = login(identifier, password);
    if (success) {
      navigate("/dashboard");
    } else {
      toast({
        title: "Erreur de connexion",
        description: "Identifiant ou mot de passe incorrect.",
        variant: "destructive",
      });
    }
  };

  return (
    <div className="relative z-10 w-full max-w-[680px] mx-4">
      <div className="rounded-sm bg-card text-card-foreground shadow-2xl px-16 py-12">
        {/* Sopra HR Logo */}
        <div className="flex justify-center mb-8">
          <SopraLogo />
        </div>

        {/* Welcome text */}
        <div className="flex items-center gap-3 mb-2">
          <div className="w-9 h-9 rounded-full bg-[hsl(var(--primary))] flex items-center justify-center text-primary-foreground text-xs font-bold">
            4YOU
          </div>
          <p className="text-lg text-card-foreground">
            <span className="font-semibold">Bienvenue Sahar sur 4YOU,</span>{" "}
            connectez-vous pour accéder à votre espace.
          </p>
        </div>

        {/* Required fields note */}
        <p className="text-sm text-muted-foreground mb-6 mt-4">
          Les champs indiqués par une <span className="text-[hsl(var(--sopra-red))]">*</span> sont obligatoires.
        </p>

        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Identifier */}
          <div>
            <label className="block text-sm font-medium text-card-foreground mb-1.5">
              Votre identifiant <span className="text-[hsl(var(--sopra-red))]">*</span>
            </label>
            <Input
              value={identifier}
              onChange={(e) => setIdentifier(e.target.value)}
              className="h-10 border-border bg-card text-card-foreground"
              required
            />
          </div>

          {/* Password */}
          <div>
            <label className="block text-sm font-medium text-card-foreground mb-1.5">
              Votre mot de passe <span className="text-[hsl(var(--sopra-red))]">*</span>
            </label>
            <div className="relative">
              <Input
                type={showPassword ? "text" : "password"}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="h-10 pr-10 border-border bg-card text-card-foreground"
                required
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-card-foreground"
              >
                {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
              </button>
            </div>
          </div>

          {/* Forgot password */}
          <a
            href="#"
            className="inline-flex items-center gap-1.5 text-sm text-[hsl(var(--link-color))] hover:underline"
          >
            <Lock className="h-3.5 w-3.5" />
            Mot de passe oublié ?
          </a>

          {/* Language */}
          <div>
            <label className="block text-sm font-medium text-card-foreground mb-1.5">
              Votre langue <span className="text-[hsl(var(--sopra-red))]">*</span>
            </label>
            <Select value={language} onValueChange={setLanguage}>
              <SelectTrigger className="h-10 border-border bg-card text-card-foreground">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="fr">🇫🇷 Français</SelectItem>
                <SelectItem value="en">🇬🇧 English</SelectItem>
                <SelectItem value="de">🇩🇪 Deutsch</SelectItem>
                <SelectItem value="es">🇪🇸 Español</SelectItem>
              </SelectContent>
            </Select>
          </div>

          {/* Submit */}
          <div className="flex justify-center pt-2">
            <Button
              type="submit"
              variant="outline"
              className="px-8 border-border text-card-foreground hover:bg-accent"
            >
              Me connecter
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
};
