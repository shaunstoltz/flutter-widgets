part of maps;

/// Base class of the map behaviors.
abstract class MapBehavior {
  // Used internally to notify all interaction changes.
  _DefaultController _controller;

  /// Render box of the map behavior.
  RenderBox renderBox;

  /// Override this method to handle pointer events that hit this render object.
  @mustCallSuper
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    _controller.notifyListeners();
  }

  /// Paint this render object into the given context at the given offset.
  void paint(PaintingContext context, Offset offset) {
    // Implement paint.
  }
}

/// Enables zooming and panning in [MapShapeLayer] and [MapTileLayer].
///
/// Zooming and panning will start working when the new instance of
/// [MapZoomPanBehavior] is set to [MapShapeLayer.zoomPanBehavior]. However,
/// if you need to restrict pinch zooming or panning for any specific
/// requirements, you can set the [enablePinching] and [enablePanning]
/// properties to false respectively.
///
/// The [focalLatLng] is the focal point of the map layer based on which zooming
/// happens.
///
/// The default [zoomLevel] value is 1 which will show the whole map in the
/// viewport for [MapShapeLayer] and the possible bounds for the [MapTileLayer]
/// based on the [focalLatLng] (Please check the documentation of [MapTileLayer]
/// to know more details about how [zoomLevel] works in it).
///
/// You can also get the current zoom level and focal position of the
/// map layer using the [zoomLevel] and [focalLatLng] after the interaction.
///
/// The minimum and maximum zooming levels can be restricted using the
/// [minZoomLevel] and [maxZoomLevel] properties respectively. The default
/// values of [minZoomLevel] and [maxZoomLevel] are 0 and 15 respectively.
/// However, for [MapTileLayer], the [maxZoomLevel] may slightly vary depends
/// on the providers. Kindly check the respective official website of the map
/// tile providers to know about the maximum zoom level it supports.
///
/// Toolbar with the the options for changing the visible bound for the web
/// platform will be enabled by default. However, you can use the [showToolbar]
/// property to changes its visibility.
///
/// The procedure and the behavior are similar for both the [MapShapeLayer]
/// and [MapTileLayer].
///
/// ```dart
///   MapZoomPanBehavior _zoomPanBehavior;
///
///   @override
///   void initState() {
///     _zoomPanBehavior = MapZoomPanBehavior()
///       ..zoomLevel = 4
///       ..focalLatLng = MapLatLng(19.0759837, 72.8776559);
///     super.initState();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(
///         title: Text('Zoom pan'),
///       ),
///       body: SfMaps(
///         layers: [
///           MapShapeLayer(
///             delegate: MapShapeLayerDelegate(
///               shapeFile: 'assets/world_map.json',
///               shapeDataField: 'continent',
///             ),
///             zoomPanBehavior: _zoomPanBehavior,
///           ),
///         ],
///       ),
///     );
///   }
/// ```
class MapZoomPanBehavior extends MapBehavior {
  /// Creates a new [MapZoomPanBehavior].
  MapZoomPanBehavior({
    double zoomLevel = 1.0,
    MapLatLng focalLatLng,
    double minZoomLevel = 1.0,
    double maxZoomLevel = 15.0,
    bool enablePinching = true,
    bool enablePanning = true,
    bool showToolbar = true,
    MapToolbarSettings toolbarSettings = const MapToolbarSettings(),
  })  : _zoomLevel = zoomLevel,
        _focalLatLng = focalLatLng,
        _minZoomLevel = minZoomLevel,
        _maxZoomLevel = maxZoomLevel,
        _enablePinching = enablePinching,
        _enablePanning = enablePanning,
        _showToolbar = showToolbar,
        _toolbarSettings = toolbarSettings;

  /// Current zoom level of the map layer.
  ///
  /// Defaults to 1.
  ///
  /// The default [zoomLevel] value is 1 which will show the whole map in the
  /// viewport for [MapShapeLayer] and the possible bounds for the
  /// [MapTileLayer] based on the [focalLatLng] (Please check the documentation
  /// of [MapTileLayer] to know more details about how [zoomLevel] works in it).
  ///
  /// You can also get the current zoom level after interaction using the
  /// [zoomLevel] property.
  double get zoomLevel => _zoomLevel;
  double _zoomLevel;
  set zoomLevel(double value) {
    assert(value >= 1);
    assert(value >= minZoomLevel && value <= maxZoomLevel);
    if (_zoomLevel == value || value < minZoomLevel || value > maxZoomLevel) {
      return;
    }
    _zoomLevel = value;
    _controller?.onZoomLevelChange(zoomLevel);
  }

  /// The [focalLatLng] is the focal point of the map layer based on which
  /// zooming happens.
  ///
  /// The default [zoomLevel] value is 1 which will show the whole map in the
  /// viewport for [MapShapeLayer] and the possible bounds for the
  /// [MapTileLayer] based on the [focalLatLng] (Please check the documentation
  /// of [MapTileLayer] to know more details about how [zoomLevel] works in it).
  MapLatLng get focalLatLng => _focalLatLng;
  MapLatLng _focalLatLng;
  set focalLatLng(MapLatLng value) {
    if (_focalLatLng == value) {
      return;
    }
    _focalLatLng = value;
    _controller?.onPanChange(value);
  }

  /// Minimum zoom level of the map layer.
  ///
  /// Defaults to 1.
  double get minZoomLevel => _minZoomLevel;
  double _minZoomLevel;
  set minZoomLevel(double value) {
    assert(value >= 1);
    if (_minZoomLevel == value) {
      return;
    }
    _minZoomLevel = value;
  }

  /// Maximum zoom level of the map layer.
  ///
  /// Defaults to 15.
  ///
  /// However, for [MapTileLayer], the [maxZoomLevel] may slightly vary depends
  /// on the providers. Kindly check the respective official website of the map
  /// tile providers to know about the maximum zoom level it supports.
  double get maxZoomLevel => _maxZoomLevel;
  double _maxZoomLevel;
  set maxZoomLevel(double value) {
    if (_maxZoomLevel == value) {
      return;
    }
    _maxZoomLevel = value;
  }

  /// Option to enable pinch zooming support.
  ///
  /// Defaults to `true`.
  ///
  /// For the web platform, track pad and mouse wheel zooming will be enabled
  /// based on this property.
  bool get enablePinching => _enablePinching;
  bool _enablePinching;
  set enablePinching(bool value) {
    if (_enablePinching == value) {
      return;
    }
    _enablePinching = value;
  }

  /// Enables panning across the map layer.
  ///
  /// Defaults to `true`.
  bool get enablePanning => _enablePanning;
  bool _enablePanning;
  set enablePanning(bool value) {
    if (_enablePanning == value) {
      return;
    }
    _enablePanning = value;
  }

  /// Shows zooming toolbar in the web platform.
  ///
  /// Defaults to `true` in web platform.
  ///
  /// However, you can use this property to changes its visibility.
  bool get showToolbar => _showToolbar;
  bool _showToolbar;
  set showToolbar(bool value) {
    if (_showToolbar == value) {
      return;
    }
    _showToolbar = value;
  }

  /// Provides options for customizing the appearance of the toolbar in thw web
  /// platform.
  MapToolbarSettings get toolbarSettings => _toolbarSettings;
  MapToolbarSettings _toolbarSettings;
  set toolbarSettings(MapToolbarSettings value) {
    if (_toolbarSettings == value) {
      return;
    }
    _toolbarSettings = value;
  }

  /// Called whenever zooming is happening.
  ///
  /// Subclasses can override this method to do any custom operations based on
  /// the details provided in the [MapZoomDetails]. When
  /// `super.onZooming(details)` is not called, zooming will not happen.
  ///
  /// [MapZoomDetails] contains following properties.
  ///  * [MapZoomDetails.previousVisibleBounds] - provides the visible bounds
  ///   before the current zooming operation completes i.e. current visible
  ///   bounds.
  ///  * [MapZoomDetails.newVisibleBounds] - provides the new visible bounds
  ///   when the current zoom completes. Hence, if the
  ///   `super.onZooming(details)` is not called, there will be no changes in
  ///   the UI.
  ///  * [MapZoomDetails.previousZoomLevel] - provides the zoom level
  ///   before the current zooming operation completes i.e. current zoom
  ///   level.
  ///  * [MapZoomDetails.newZoomLevel] - provides the new zoom level
  ///   when the current zoom completes. Hence, if the
  ///   `super.onZooming(details)` is not called, there will be no
  ///   changes in the UI.
  ///  * [MapZoomDetails.globalFocalPoint] - The global focal point of the
  ///  pointers in contact with the screen.
  ///  * [MapZoomDetails.localFocalPoint] - The local focal point of the
  ///   pointers in contact with the screen.
  void onZooming(MapZoomDetails details) {
    if (_controller != null) {
      _controller.notifyZoomingListeners(details);
      _controller.notifyListeners();
    }
  }

  /// Called whenever panning is happening.
  ///
  /// Subclasses can override this method to do any custom operations based on
  /// the details provided in the [MapPanDetails]. When
  /// `super.onPanning(details)` is not called, panning will not happen.
  ///
  /// [MapPanDetails] contains following properties.
  ///  * [MapPanDetails.previousVisibleBounds] - provides the visible bounds
  ///   before the current panning operation completes i.e. current visible
  ///   bounds.
  ///  * [MapPanDetails.newVisibleBounds] - provides the new visible bounds
  ///   when the current pan completes. Hence, if the
  ///   `super.onPanning(details)` is not called, there will be no changes in
  ///   the UI.
  ///  * [MapPanDetails.zoomLevel] - provides the current zoom level.
  ///  * [MapPanDetails.delta] - The difference in pixels between touch start
  ///  and current touch position.
  ///  * [MapPanDetails.globalFocalPoint] - The global focal point of the
  ///  pointers in contact with the screen.
  ///  * [MapPanDetails.localFocalPoint] - The local focal point of the
  ///   pointers in contact with the screen.
  void onPanning(MapPanDetails details) {
    if (_controller != null) {
      _controller.notifyPanningListeners(details);
      _controller.notifyListeners();
    }
  }

  /// When this method is called, the map will be reset to the
  /// [MapZoomPanBehavior.minZoomLevel].
  void reset() {
    _controller.notifyResetListeners();
    _controller.notifyListeners();
  }
}

/// Latitude and longitude in the maps.
@immutable
class MapLatLng {
  /// Creates a [MapLatLng].
  const MapLatLng(
    this.latitude,
    this.longitude,
  );

  /// The latitude in the maps.
  final double latitude;

  /// The longitude in the maps.
  final double longitude;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    return other is MapLatLng &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => hashValues(latitude, longitude);

  @override
  String toString() =>
      'MapLatLng(${latitude.toString()}, ${longitude.toString()})';
}

/// Bounds of the maps.
@immutable
class MapLatLngBounds {
  /// Creates a [MapLatLngBounds].
  const MapLatLngBounds(this.northeast, this.southwest);

  /// The north east [MapLatLng].
  final MapLatLng northeast;

  /// The southwest [MapLatLng].
  final MapLatLng southwest;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    return other is MapLatLngBounds &&
        other.northeast == northeast &&
        other.southwest == southwest;
  }

  @override
  int get hashCode => hashValues(northeast, southwest);

  @override
  String toString() =>
      'MapLatLngBounds(${northeast.toString()}, ${southwest.toString()})';
}

/// Contains details about the current zoom position.
class MapZoomDetails {
  /// Creates a [MapZoomDetails].
  MapZoomDetails({
    this.localFocalPoint,
    this.globalFocalPoint,
    this.previousZoomLevel,
    this.newZoomLevel,
    this.previousVisibleBounds,
    this.newVisibleBounds,
  });

  /// The global focal point of the pointers in contact with the screen.
  final Offset globalFocalPoint;

  /// The local focal point of the pointers in contact with the screen.
  final Offset localFocalPoint;

  /// Provides the zoom level before the current zooming operation completes
  /// i.e. current zoom level.
  final double previousZoomLevel;

  /// Provides the new zoom level when the current zoom completes.
  ///
  /// Hence, if the `super.onZooming(details)` is not called, there will be no
  /// changes in the UI.
  final double newZoomLevel;

  /// Provides the visible bounds before the current zooming operation completes
  /// i.e. current visible bounds.
  final MapLatLngBounds previousVisibleBounds;

  /// Provides the new visible bounds when the current zoom completes.
  ///
  /// Hence, if the `super.onZooming(details)` is not called, there will be no
  /// changes in the UI.
  final MapLatLngBounds newVisibleBounds;

  MapLatLng _newFocalLatLng;
}

/// Contains details about the current pan position.
class MapPanDetails {
  /// Creates a [MapPanDetails].
  MapPanDetails({
    this.zoomLevel,
    this.delta,
    this.previousVisibleBounds,
    this.newVisibleBounds,
    this.globalFocalPoint,
    this.localFocalPoint,
  });

  /// Provides the current zoom level.
  final double zoomLevel;

  /// The difference in pixels between touch start and current touch position.
  final Offset delta;

  /// Provides the visible bounds before the current panning operation
  /// completes i.e. current visible bounds.
  final MapLatLngBounds previousVisibleBounds;

  /// Provides the new visible bounds when the current pan completes.
  ///
  /// Hence, if the `super.onPanning(details)` is not called, there will be no
  /// changes in the UI.
  final MapLatLngBounds newVisibleBounds;

  /// The global focal point of the pointers in contact with the screen.
  final Offset globalFocalPoint;

  /// The local focal point of the pointers in contact with the screen.
  final Offset localFocalPoint;

  MapLatLng _newFocalLatLng;
}

class _BehaviorViewRenderObjectWidget extends LeafRenderObjectWidget {
  const _BehaviorViewRenderObjectWidget({
    Key key,
    this.defaultController,
    this.zoomPanBehavior,
  }) : super(key: key);

  final _DefaultController defaultController;

  final MapZoomPanBehavior zoomPanBehavior;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderBehaviorView(
      listener: defaultController,
      zoomPanBehavior: zoomPanBehavior,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderBehaviorView renderObject) {
    renderObject
      ..defaultController = defaultController
      ..zoomPanBehavior = zoomPanBehavior;
  }
}

class _RenderBehaviorView extends RenderBox {
  _RenderBehaviorView({
    _DefaultController listener,
    MapZoomPanBehavior zoomPanBehavior,
  })  : defaultController = listener,
        _zoomPanBehavior = zoomPanBehavior {
    _zoomPanBehavior.renderBox = this;
  }

  _DefaultController defaultController;

  MapZoomPanBehavior get zoomPanBehavior => _zoomPanBehavior;
  MapZoomPanBehavior _zoomPanBehavior;
  set zoomPanBehavior(MapZoomPanBehavior value) {
    if (_zoomPanBehavior == value) {
      return;
    }
    _zoomPanBehavior = value;
    value.renderBox = this;
  }

  void _handleBehaviorChange() {
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    defaultController.addListener(_handleBehaviorChange);
  }

  @override
  void detach() {
    defaultController.removeListener(_handleBehaviorChange);
    super.detach();
  }

  @override
  bool hitTestSelf(Offset position) => false;

  @override
  void performLayout() {
    size = _getBoxSize(constraints);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    zoomPanBehavior?.paint(context, offset);
    super.paint(context, offset);
  }
}
