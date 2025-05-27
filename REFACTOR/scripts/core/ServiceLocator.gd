class_name ServiceLocator
extends RefCounted

## ServiceLocator - Centralized Dependency Injection System
##
## This class provides a centralized way to register and access services throughout
## the application. It implements the Service Locator pattern to manage dependencies
## and reduce tight coupling between components.
##
## Usage:
##   # Register a service
##   ServiceLocator.register_service(ServiceLocator.AUDIO_MANAGER, audio_manager_instance)
##   
##   # Get a service
##   var audio_manager = ServiceLocator.get_service(ServiceLocator.AUDIO_MANAGER)
##
## @tutorial: https://gameprogrammingpatterns.com/service-locator.html

# Singleton instance for global access
static var _instance: ServiceLocator
static var _services: Dictionary = {}

## Service name constants - centralized service identifiers
const AUDIO_MANAGER = "audio_manager"
const PARAMETER_MANAGER = "parameter_manager"
const COLOR_PALETTE_MANAGER = "color_palette_manager"
const SHADER_MANAGER = "shader_manager"
const SCREENSHOT_MANAGER = "screenshot_manager"
const TIMELINE_MANAGER = "timeline_manager"
const INPUT_MANAGER = "input_manager"
const MENU_MANAGER = "menu_manager"
const CONFIG_MANAGER = "config_manager"

## Get the singleton instance
static func get_instance() -> ServiceLocator:
	if not _instance:
		_instance = ServiceLocator.new()
	return _instance

## Register a service with the locator
## @param service_name: Unique identifier for the service (use constants above)
## @param service_instance: The service instance to register
static func register_service(service_name: String, service_instance) -> void:
	if not service_instance:
		push_error("ServiceLocator: Cannot register null service '%s'" % service_name)
		return
	
	if service_name in _services:
		push_warning("ServiceLocator: Overwriting existing service '%s'" % service_name)
	
	_services[service_name] = service_instance
	print("ServiceLocator: Registered service '%s' (%s)" % [service_name, service_instance.get_class()])

## Get a service from the locator
## @param service_name: The service identifier
## @return: The service instance, or null if not found
static func get_service(service_name: String):
	if service_name in _services:
		return _services[service_name]
	else:
		push_error("ServiceLocator: Service '%s' not found! Available services: %s" % [service_name, _services.keys()])
		return null

## Check if a service is registered
## @param service_name: The service identifier
## @return: True if the service is registered
static func has_service(service_name: String) -> bool:
	return service_name in _services

## Unregister a service
## @param service_name: The service identifier to remove
static func unregister_service(service_name: String) -> void:
	if service_name in _services:
		var service = _services[service_name]
		_services.erase(service_name)
		print("ServiceLocator: Unregistered service '%s'" % service_name)
		
		# Call cleanup if the service has it
		if service.has_method("cleanup"):
			service.cleanup()
	else:
		push_warning("ServiceLocator: Attempted to unregister non-existent service '%s'" % service_name)

## Clear all registered services (useful for cleanup)
static func clear_all_services() -> void:
	print("ServiceLocator: Clearing all services...")
	
	# Call cleanup on all services that support it
	for service_name in _services:
		var service = _services[service_name]
		if service and service.has_method("cleanup"):
			print("ServiceLocator: Cleaning up service '%s'" % service_name)
			service.cleanup()
	
	_services.clear()
	print("ServiceLocator: All services cleared")

## Get all registered service names (for debugging)
## @return: Array of service names
static func get_registered_services() -> Array:
	return _services.keys()

## Get detailed information about all services (for debugging)
## @return: Dictionary with service information
static func get_service_info() -> Dictionary:
	var info = {}
	for service_name in _services:
		var service = _services[service_name]
		info[service_name] = {
			"class": service.get_class() if service else "null",
			"instance_id": service.get_instance_id() if service else -1,
			"has_cleanup": service.has_method("cleanup") if service else false
		}
	return info

## Validate that all required services are registered
## @param required_services: Array of service names that must be present
## @return: True if all required services are registered
static func validate_required_services(required_services: Array) -> bool:
	var missing_services = []
	
	for service_name in required_services:
		if not has_service(service_name):
			missing_services.append(service_name)
	
	if missing_services.size() > 0:
		push_error("ServiceLocator: Missing required services: %s" % missing_services)
		return false
	
	return true

## Get multiple services at once
## @param service_names: Array of service names to retrieve
## @return: Dictionary mapping service names to instances
static func get_services(service_names: Array) -> Dictionary:
	var services = {}
	for service_name in service_names:
		services[service_name] = get_service(service_name)
	return services

## Register multiple services at once
## @param services_dict: Dictionary mapping service names to instances
static func register_services(services_dict: Dictionary) -> void:
	for service_name in services_dict:
		register_service(service_name, services_dict[service_name])
