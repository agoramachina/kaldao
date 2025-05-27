class_name ServiceLocator
extends RefCounted

# Singleton pattern for global service access
static var _instance: ServiceLocator
static var _services: Dictionary = {}

static func get_instance() -> ServiceLocator:
	if not _instance:
		_instance = ServiceLocator.new()
	return _instance

static func register_service(service_name: String, service_instance):
	_services[service_name] = service_instance
	print("ServiceLocator: Registered service '%s'" % service_name)

static func get_service(service_name: String):
	if service_name in _services:
		return _services[service_name]
	else:
		push_error("ServiceLocator: Service '%s' not found!" % service_name)
		return null

static func unregister_service(service_name: String):
	if service_name in _services:
		_services.erase(service_name)
		print("ServiceLocator: Unregistered service '%s'" % service_name)

static func clear_all_services():
	_services.clear()
	print("ServiceLocator: All services cleared")

# Service name constants
const PARAMETER_MANAGER = "parameter_manager"
const COLOR_PALETTE_MANAGER = "color_palette_manager"
const SHADER_CONTROLLER = "shader_controller"
const AUDIO_MANAGER = "audio_manager"
const SCREENSHOT_MANAGER = "screenshot_manager"
const SONG_SETTINGS = "song_settings"
