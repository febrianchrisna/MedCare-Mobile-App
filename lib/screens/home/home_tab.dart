import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_carousel_widget/flutter_carousel_widget.dart'; // Replace carousel_slider
import 'package:medcareapp/models/medicine.dart';
import 'package:medcareapp/providers/medicine_provider.dart';
import 'package:medcareapp/screens/medicine/medicine_detail_screen.dart';
import 'package:medcareapp/screens/medicine/medicine_list_screen.dart';
import 'package:medcareapp/utils/theme.dart';
import 'package:medcareapp/utils/constants.dart';
import 'package:medcareapp/widgets/medicine_card.dart';
import 'package:medcareapp/widgets/category_card.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Health Essentials',
      'subtitle': 'Up to 30% off on vitamins',
      'color': AppTheme.primaryColor,
    },
    {
      'title': 'New Arrivals',
      'subtitle': 'Check out our latest products',
      'color': AppTheme.accentColor,
    },
    {
      'title': 'Healthcare Solutions',
      'subtitle': 'Free delivery on orders over \$50',
      'color': AppTheme.warningColor,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure this runs after the initial build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Initialize medicines if needed
        final provider = Provider.of<MedicineProvider>(context, listen: false);
        if (provider.state == ProviderState.initial) {
          provider.initializeMedicines();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final medicineProvider = Provider.of<MedicineProvider>(context);

    // Show loading indicator if provider is still initializing
    if (medicineProvider.state == ProviderState.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Show error if there was a problem loading data
    if (medicineProvider.state == ProviderState.error) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: ${medicineProvider.error}'),
              ElevatedButton(
                onPressed: () => medicineProvider.initializeMedicines(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final featuredMedicines = medicineProvider.featuredMedicines;
    final categories = medicineProvider.categories;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => medicineProvider.initializeMedicines(),
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: false,
              pinned: true,
              title: const Text('MedCare'),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carousel Banner
                    FlutterCarousel(
                      items:
                          _banners.map((item) {
                            return Builder(
                              builder: (BuildContext context) {
                                return Container(
                                  width: MediaQuery.of(context).size.width,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 5.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item['color'].withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        right: -30,
                                        bottom: -30,
                                        child: Icon(
                                          Icons.healing,
                                          size: 150,
                                          color: item['color'].withOpacity(0.1),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              item['title'],
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              item['subtitle'],
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) =>
                                                            const MedicineListScreen(),
                                                  ),
                                                );
                                              },
                                              child: const Text('Shop Now'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }).toList(),
                      options: CarouselOptions(
                        height: 180,
                        aspectRatio: 16 / 9,
                        viewportFraction: 0.9,
                        initialPage: 0,
                        enableInfiniteScroll: true,
                        autoPlay: true,
                      ),
                    ),

                    // Categories Section
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Categories',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const MedicineListScreen(),
                                    ),
                                  );
                                },
                                child: const Text('See All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 100,
                            child:
                                medicineProvider.categories.isEmpty
                                    ? const Center(
                                      child: Text('No categories available'),
                                    )
                                    : ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount:
                                          medicineProvider.categories.length,
                                      itemBuilder: (context, index) {
                                        return CategoryCard(
                                          title:
                                              medicineProvider
                                                  .categories[index],
                                          onTap: () {
                                            // Navigate to filtered medicines by category
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => MedicineListScreen(
                                                      category:
                                                          medicineProvider
                                                              .categories[index],
                                                    ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                    ),

                    // Featured Medicines Section
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Featured Medicines',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              TextButton(
                                onPressed: () {
                                  // Navigate to featured medicines page
                                },
                                child: const Text('See All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 250,
                            child:
                                medicineProvider.isLoading
                                    ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                    : featuredMedicines.isEmpty
                                    ? const Center(
                                      child: Text(
                                        'No featured medicines available',
                                      ),
                                    )
                                    : ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: featuredMedicines.length,
                                      itemBuilder: (context, index) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12.0,
                                          ),
                                          child: SizedBox(
                                            width: 160,
                                            child: MedicineCard(
                                              medicine:
                                                  featuredMedicines[index],
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (
                                                          _,
                                                        ) => MedicineDetailScreen(
                                                          medicineId:
                                                              featuredMedicines[index]
                                                                  .id!,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                          ),
                        ],
                      ),
                    ),

                    // Latest Medicines Section
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Latest Medicines',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const MedicineListScreen(),
                                    ),
                                  );
                                },
                                child: const Text('See All'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          medicineProvider.isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : medicineProvider.medicines.isEmpty
                              ? const Center(
                                child: Text('No medicines available'),
                              )
                              : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.7,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                itemCount:
                                    medicineProvider.medicines.length > 4
                                        ? 4
                                        : medicineProvider.medicines.length,
                                itemBuilder: (context, index) {
                                  return MedicineCard(
                                    medicine: medicineProvider.medicines[index],
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => MedicineDetailScreen(
                                                medicineId:
                                                    medicineProvider
                                                        .medicines[index]
                                                        .id!,
                                              ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
