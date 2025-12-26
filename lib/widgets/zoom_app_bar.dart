import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/zoom_provider.dart';

class ZoomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double? elevation;
  final Color? backgroundColor;
  final IconThemeData? iconTheme;
  final IconThemeData? actionsIconTheme;
  final SystemUiOverlayStyle? systemOverlayStyle;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final double? toolbarHeight;
  final double? leadingWidth;
  final bool primary;
  final FlexibleSpaceBar? flexibleSpace;
  final ShapeBorder? shape;
  final Color? foregroundColor;

  const ZoomAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation,
    this.backgroundColor,
    this.iconTheme,
    this.actionsIconTheme,
    this.systemOverlayStyle,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.toolbarHeight,
    this.leadingWidth,
    this.primary = true,
    this.flexibleSpace,
    this.shape,
    this.foregroundColor,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        toolbarHeight ?? kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  Future<void> _showZoomMenu(BuildContext context, Offset position) async {
    final zoomProvider = Provider.of<ZoomProvider>(context, listen: false);
    
    await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'zoom_in',
          child: const Row(
            children: [
              Icon(Icons.zoom_in, size: 20),
              SizedBox(width: 8),
              Text('Zväčšiť'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'zoom_out',
          child: const Row(
            children: [
              Icon(Icons.zoom_out, size: 20),
              SizedBox(width: 8),
              Text('Zmenšiť'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'reset',
          child: const Row(
            children: [
              Icon(Icons.refresh, size: 20),
              SizedBox(width: 8),
              Text('Resetovať (100%)'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'custom',
          child: const Row(
            children: [
              Icon(Icons.tune, size: 20),
              SizedBox(width: 8),
              Text('Vlastné zväčšenie...'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: Consumer<ZoomProvider>(
            builder: (context, zoom, child) {
              return Text(
                'Aktuálne: ${(zoom.zoomLevel * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              );
            },
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'zoom_in':
            zoomProvider.zoomIn();
            break;
          case 'zoom_out':
            zoomProvider.zoomOut();
            break;
          case 'reset':
            zoomProvider.resetZoom();
            break;
          case 'custom':
            _showZoomDialog(context, zoomProvider);
            break;
        }
      }
    });
  }

  Future<void> _showZoomDialog(BuildContext context, ZoomProvider zoomProvider) async {
    final zoomController = TextEditingController(
      text: (zoomProvider.zoomLevel * 100).toStringAsFixed(0),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.zoom_in),
            SizedBox(width: 8),
            Text('Zväčšenie aplikácie'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Zadajte zväčšenie v percentách (50% - 200%):'),
            const SizedBox(height: 16),
            TextField(
              controller: zoomController,
              decoration: const InputDecoration(
                labelText: 'Zväčšenie (%)',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      zoomProvider.setZoomLevel(0.75);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.zoom_out),
                    label: const Text('75%'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      zoomProvider.setZoomLevel(1.0);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('100%'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      zoomProvider.setZoomLevel(1.25);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('125%'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      zoomProvider.setZoomLevel(1.5);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.zoom_in),
                    label: const Text('150%'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zrušiť'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(zoomController.text);
              if (value != null && value >= 50 && value <= 200) {
                zoomProvider.setZoomLevel(value / 100);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Zadajte platnú hodnotu medzi 50 a 200'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Použiť'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showZoomMenu(context, details.globalPosition);
      },
      child: AppBar(
        title: title,
        actions: actions,
        leading: leading,
        centerTitle: centerTitle,
        elevation: elevation,
        backgroundColor: backgroundColor,
        iconTheme: iconTheme,
        actionsIconTheme: actionsIconTheme,
        systemOverlayStyle: systemOverlayStyle,
        automaticallyImplyLeading: automaticallyImplyLeading,
        bottom: bottom,
        toolbarHeight: toolbarHeight,
        leadingWidth: leadingWidth,
        primary: primary,
        flexibleSpace: flexibleSpace,
        shape: shape,
        foregroundColor: foregroundColor,
      ),
    );
  }
}

