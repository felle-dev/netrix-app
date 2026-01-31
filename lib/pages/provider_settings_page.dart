import 'package:flutter/material.dart';
import '../models/ip_provider.dart';

class ProviderSettingsPage extends StatefulWidget {
  final List<IPProvider> providers;
  final int selectedProviderIndex;
  final Function(int) onSelectProvider;
  final Function(IPProvider) onAddProvider;
  final Future<bool> Function(int) onDeleteProvider;
  final Function() onResetToDefaults;

  const ProviderSettingsPage({
    Key? key,
    required this.providers,
    required this.selectedProviderIndex,
    required this.onSelectProvider,
    required this.onAddProvider,
    required this.onDeleteProvider,
    required this.onResetToDefaults,
  }) : super(key: key);

  @override
  State<ProviderSettingsPage> createState() => _ProviderSettingsPageState();
}

class _ProviderSettingsPageState extends State<ProviderSettingsPage> {
  final _nameController = TextEditingController();
  final _ipUrlController = TextEditingController();
  final _detailsUrlController = TextEditingController();
  final _jsonKeyController = TextEditingController();

  late List<IPProvider> _providers;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _providers = List.from(widget.providers);
    _selectedIndex = widget.selectedProviderIndex;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipUrlController.dispose();
    _detailsUrlController.dispose();
    _jsonKeyController.dispose();
    super.dispose();
  }

  void _showAddProviderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Custom Provider'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Provider Name',
                  hintText: 'e.g., MyIPService',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ipUrlController,
                decoration: const InputDecoration(
                  labelText: 'IP URL',
                  hintText: 'https://api.example.com/ip',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _jsonKeyController,
                decoration: const InputDecoration(
                  labelText: 'IP JSON Key',
                  hintText: 'ip',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsUrlController,
                decoration: const InputDecoration(
                  labelText: 'Details URL (optional)',
                  hintText: 'Use {ip} as placeholder',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty &&
                  _ipUrlController.text.isNotEmpty &&
                  _jsonKeyController.text.isNotEmpty) {
                final provider = IPProvider(
                  name: _nameController.text,
                  ipUrl: _ipUrlController.text,
                  detailsUrl: _detailsUrlController.text,
                  ipJsonKey: _jsonKeyController.text,
                );

                widget.onAddProvider(provider);
                setState(() {
                  _providers.add(provider);
                });

                _nameController.clear();
                _ipUrlController.clear();
                _detailsUrlController.clear();
                _jsonKeyController.clear();
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Provider added successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will restore all default providers and remove any custom providers you\'ve added. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onResetToDefaults();
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IP Provider Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to defaults',
            onPressed: _showResetConfirmDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add provider',
            onPressed: _showAddProviderDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Select which provider to use for checking your IP',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_providers.isEmpty)
            _buildEmptyState(theme)
          else
            ..._buildProviderList(theme),
          const SizedBox(height: 16),
          _buildInfoBox(theme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.dns_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No providers available',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add a provider',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProviderList(ThemeData theme) {
    return _providers.asMap().entries.map((entry) {
      final index = entry.key;
      final provider = entry.value;
      final isSelected = _selectedIndex == index;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedIndex = index;
              });
              widget.onSelectProvider(index);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          provider.ipUrl,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: () async {
                      final deleted = await widget.onDeleteProvider(index);
                      if (!deleted && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot delete the last provider'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else if (mounted) {
                        setState(() {
                          _providers.removeAt(index);
                          if (_selectedIndex >= _providers.length) {
                            _selectedIndex = _providers.length - 1;
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Provider deleted'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildInfoBox(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.tertiary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.tertiary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Select a provider and the app will use it for all checks. You can delete any provider except the last one.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
