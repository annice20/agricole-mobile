import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../core/api_client.dart';
import '../../models/utilisateur.dart';
import '../../services/profil_service.dart';
import '../../widgets/app_layout.dart';

class ProfilPage extends StatefulWidget {
  const ProfilPage({super.key});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  Utilisateur? profil;
  int? _userId;

  bool loading = true;
  bool enregistrement = false;
  bool changementMdp = false;

  final nomController = TextEditingController();
  final prenomController = TextEditingController();
  final telephoneController = TextEditingController();

  final ancienMdpController = TextEditingController();

  final nouveauMdpController = TextEditingController();

  final confirmationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    chargerProfil();
  }

  Future<void> chargerProfil() async {
    try {
      final session = await ApiClient().getSession();
      if (session == null) {
        throw Exception("Session introuvable, veuillez vous reconnecter");
      }
      _userId = session.id;

      final user = await ProfilService.getProfil(_userId!);

      setState(() {
        profil = user;

        nomController.text = user.nom;
        prenomController.text = user.prenom;
        telephoneController.text = user.telephone;

        loading = false;
      });
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> enregistrerInfos() async {
    if (profil == null || _userId == null) return;

    setState(() {
      enregistrement = true;
    });

    try {
      final user = await ProfilService.modifierProfil(_userId!, {
        "nom": nomController.text,
        "prenom": prenomController.text,
        "telephone": telephoneController.text,
      });

      setState(() {
        profil = user;
      });

      Fluttertoast.showToast(msg: "Profil mis à jour avec succès");
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }

    setState(() {
      enregistrement = false;
    });
  }

  Future<void> modifierMotDePasse() async {
    if (profil == null || _userId == null) return;

    if (nouveauMdpController.text != confirmationController.text) {
      Fluttertoast.showToast(msg: "Les mots de passe ne correspondent pas");
      return;
    }

    if (nouveauMdpController.text.length < 6) {
      Fluttertoast.showToast(msg: "Minimum 6 caractères");
      return;
    }

    setState(() {
      changementMdp = true;
    });

    try {
      await ProfilService.changerMotDePasse(_userId!, {
        "ancienMotDePasse": ancienMdpController.text,
        "nouveauMotDePasse": nouveauMdpController.text,
      });

      ancienMdpController.clear();
      nouveauMdpController.clear();
      confirmationController.clear();

      Fluttertoast.showToast(msg: "Mot de passe modifié avec succès");
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString());
    }

    setState(() {
      changementMdp = false;
    });
  }

  Widget champ(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppLayout(
        currentRoute: "/profil",
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (profil == null) {
      return const AppLayout(
        currentRoute: "/profil",
        child: Center(child: Text("Impossible de charger le profil")),
      );
    }

    return AppLayout(
      currentRoute: "/profil",
      child: Container(
        color: const Color(0xFFE8F5E9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.green,
                        child: Text(
                          profil!.nom.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "${profil!.prenom} ${profil!.nom}",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(profil!.email),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        children: profil!.roles
                            .map(
                              (e) => Chip(
                                label: Text(e),
                                backgroundColor: Colors.green,
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        "Informations personnelles",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      champ("Nom", nomController),
                      champ("Prénom", prenomController),
                      champ("Téléphone", telephoneController),
                      champ(
                        "Email",
                        TextEditingController(text: profil!.email),
                        enabled: false,
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: enregistrement ? null : enregistrerInfos,
                          child: Text(
                            enregistrement
                                ? "Enregistrement..."
                                : "Enregistrer les modifications",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        "Changer le mot de passe",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      champ(
                        "Mot de passe actuel",
                        ancienMdpController,
                        obscure: true,
                      ),
                      champ(
                        "Nouveau mot de passe",
                        nouveauMdpController,
                        obscure: true,
                      ),
                      champ(
                        "Confirmer le mot de passe",
                        confirmationController,
                        obscure: true,
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: changementMdp ? null : modifierMotDePasse,
                          child: Text(
                            changementMdp
                                ? "Modification..."
                                : "Modifier le mot de passe",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
