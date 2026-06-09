import 'package:flutter/material.dart';
import '../../core/storage/local_storage.dart';
import '../dashboard/dashboard_screen.dart';
import '../vehicles/vehicles_screen.dart';
import '../profile/profile_screen.dart';
import '../incidents/request_incident_screen.dart';
import '../technician/technician_dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _loading = true;
  bool _isTechnician = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final user = await LocalStorage.getUser();
    final isTech = user?.roles.any((r) => r.name == 'technician') ?? false;

    if (mounted) {
      setState(() {
        _isTechnician = isTech;
        _screens = isTech
            ? [
                const TechnicianDashboardScreen(),
                const ProfileScreen(),
              ]
            : [
                const DashboardScreen(),
                const VehiclesScreen(),
                RequestIncidentScreen(),
                const ProfileScreen(),
              ];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNavTap,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.05),
        elevation: 0,
        destinations: _isTechnician
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Perfil',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart_rounded),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.directions_car_outlined),
                  selectedIcon: Icon(Icons.directions_car_rounded),
                  label: 'Mis Vehículos',
                ),
                NavigationDestination(
                  icon: Icon(Icons.sos_outlined),
                  selectedIcon: Icon(Icons.sos_rounded),
                  label: 'Auxilio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Perfil',
                ),
              ],
      ),
    );
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
  }
}
