import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pages/auth/login_page.dart';
import 'pages/auth/verification_otp_page.dart';
import 'pages/auth/mot_de_passe_oublie_page.dart';
import 'pages/agriculteurs/inscription_page.dart';
import 'pages/admin/creer_utilisateur_page.dart';
import 'pages/admin/liste_utilisateurs_page.dart';
import 'pages/agriculteurs/liste_agriculteurs_page.dart';
import 'pages/agriculteurs/ajouter_agriculteur_page.dart';
import 'pages/agriculteurs/modifier_agriculteur_page.dart';
import 'pages/programmes/liste_programmes_page.dart';
import 'pages/programmes/ajouter_modifier_programme_page.dart';
import 'pages/dashboard/dashboard_page.dart';
import 'pages/demandes/mes_demandes_page.dart';
import 'pages/demandes/gestion_demandes_page.dart';
import 'pages/agriculteurs/carte_agricole_page.dart';
import 'pages/distributions/liste_distributions_page.dart';
import 'pages/distributions/ajouter_distribution_page.dart';
import 'pages/admin/rappel_administratif_page.dart';
import 'pages/agriculteurs/mes_aides_page.dart';
import 'pages/notifications_page.dart';
import 'pages/agriculteurs/reclamation_page.dart';
import 'pages/agriculteurs/gestion_reclamations_page.dart';
import 'pages/auth/profil_page.dart';
import 'pages/financements/financements_agricoles_page.dart';
import 'pages/equipements/liste_equipements_page.dart';
import 'pages/agriculteurs/beneficiaires_regionaux_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  runApp(const AgroPlatformeApp());
}

class AgroPlatformeApp extends StatelessWidget {
  const AgroPlatformeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgroPlateforme Madagascar',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF16A34A),
          primary: const Color(0xFF16A34A),
          secondary: const Color(0xFF15803D),
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif',
      ),

      initialRoute: '/',

      routes: {
        // ── Authentification ──────────────────────────────────────
        '/': (context) => const LoginPage(),
        '/verification-otp': (context) => const VerificationOtpPage(),
        '/mot-de-passe-oublie': (context) => const MotDePasseOubliePage(),
        '/profil': (context) => const ProfilPage(),
        '/creer-utilisateur': (context) => const ListeUtilisateursPage(),
        '/creer-utilisateur/nouveau': (context) => const CreerUtilisateurPage(),

        // ── Agriculteurs ──────────────────────────────────────────
        '/inscription': (context) => const InscriptionPage(),
        '/agriculteurs': (context) => const ListeAgriculteursPage(),
        '/agriculteurs/ajouter': (context) => const AjouterAgriculteurPage(),
        '/agriculteurs/modifier': (context) => const ModifierAgriculteurPage(),
        '/carte': (context) => const CarteAgricolePage(),
        '/reclamations': (context) => const GestionReclamationsPage(),
        '/reclamations/nouvelle': (context) => const ReclamationPage(),
        '/beneficiaires-regionaux': (context) =>
            const BeneficiairesRegionauxPage(),

        // ── Programmes d'aide & Distributions ─────────────────────
        '/programmes': (context) => const ListeProgrammesPage(),
        '/programmes/ajouter': (context) =>
            const AjouterModifierProgrammePage(),
        '/programmes/modifier': (context) =>
            const AjouterModifierProgrammePage(),
        '/distributions': (context) => const ListeDistributionsPage(),
        '/distributions/ajouter': (context) => const AjouterDistributionPage(),

        '/financements': (context) => const FinancementsAgricolesPage(),
        '/equipements': (context) => const ListeEquipementsPage(),

        // ── Mes Aides ─────────────────────────────────────────────
        '/mes-aides': (context) => const MesAidesPage(),

        // ── Dashboard & Demandes ──────────────────────────────────
        '/dashboard': (context) => const DashboardPage(),
        '/mes-demandes': (context) => const MesDemandesPage(),
        '/rappel-administratif': (context) => const RappelAdministratifPage(),

        // ── Notifications ─────────────────────────────────────────
        '/notifications': (context) => const NotificationsPage(),
      },

      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '/');
        if (uri == null) return null;

        if (uri.path == '/mes-aides') {
          return MaterialPageRoute(
            settings: settings, // conserve settings.name (avec la query)
            builder: (context) => const MesAidesPage(),
          );
        }

        if (uri.path == '/demandes') {
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const GestionDemandesPage(),
          );
        }

        // Route réellement inconnue : laisse Flutter gérer l'erreur
        // normalement (ne masque pas les vraies erreurs de navigation).
        return null;
      },
    );
  }
}
