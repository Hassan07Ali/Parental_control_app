import 'package:flutter/material.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

class AppSelectorScreen extends StatefulWidget {
  const AppSelectorScreen({super.key});

  @override
  State<AppSelectorScreen> createState() => _AppSelectorScreenState();
}

class _AppSelectorScreenState extends State<AppSelectorScreen> {
  List<AppInfo> _installedApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    List<AppInfo> apps = await InstalledApps.getInstalledApps(
      excludeSystemApps: true,
      excludeNonLaunchableApps: true,
      withIcon: true,
    );

    apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (mounted) {
      setState(() {
        _installedApps = apps;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Application'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _installedApps.length,
              itemBuilder: (context, index) {
                AppInfo app = _installedApps[index];
                return ListTile(
                  leading: app.icon != null
                      ? Image.memory(app.icon!, width: 40, height: 40)
                      : const Icon(Icons.android),
                  title: Text(app.name),
                  subtitle: Text(app.packageName),
                  onTap: () {
                    // Return both the name and the package identifier
                    Navigator.pop(context, {
                      'name': app.name,
                      'package': app.packageName,
                    });
                  },
                );
              },
            ),
    );
  }
}