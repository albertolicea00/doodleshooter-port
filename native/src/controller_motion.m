// Native Apple GameController motion bridge for Godot 4.5+.
// Reads GCMotion rotationRate + gravity from connected controllers (DualShock 4,
// DualSense, etc.) and feeds gravity-aligned pitch and yaw into Input.set_gyroscope()
// whenever a motion-capable controller is connected. When no motion controller is
// connected (for example handheld iPhone/iPad touch play), Input's built-in device
// gyroscope is left untouched.

#import <Foundation/Foundation.h>
#import <GameController/GameController.h>
#include <TargetConditionals.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "gdextension_interface.h"

static GDExtensionInterfaceStringNameNewWithLatin1Chars g_sn_new = NULL;
static GDExtensionInterfaceVariantGetPtrDestructor g_get_dtor = NULL;
static GDExtensionInterfaceGlobalGetSingleton g_get_singleton = NULL;
static GDExtensionInterfaceClassdbGetMethodBind g_get_method_bind = NULL;
static GDExtensionInterfaceObjectMethodBindPtrcall g_ptrcall = NULL;
static GDExtensionInterfaceRegisterMainLoopCallbacks g_reg_callbacks = NULL;

static GDExtensionObjectPtr g_input_singleton = NULL;
static GDExtensionMethodBindPtr g_set_gyro_bind = NULL;
static bool g_skip_for_automated_run = false;
static bool g_had_motion_controller = false;

static void controller_motion_startup(void) {
	@autoreleasepool {
		NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
		for (NSString *arg in args) {
			if ([arg isEqualToString:@"--smoke"] || [arg isEqualToString:@"--capture"]) {
				g_skip_for_automated_run = true;
				return;
			}
		}
#if TARGET_OS_OSX
		if (@available(macOS 11.3, *)) {
			GCController.shouldMonitorBackgroundEvents = YES;
		}
#endif
		if (!g_sn_new || !g_get_dtor || !g_get_singleton || !g_get_method_bind || !g_ptrcall) {
			return;
		}
		GDExtensionPtrDestructor sn_dtor = g_get_dtor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
		uint64_t sn_input[1] = {0};
		uint64_t sn_method[1] = {0};
		g_sn_new((GDExtensionUninitializedStringNamePtr)sn_input, "Input", false);
		g_sn_new((GDExtensionUninitializedStringNamePtr)sn_method, "set_gyroscope", false);
		g_input_singleton = g_get_singleton((GDExtensionConstStringNamePtr)sn_input);
		if (g_input_singleton) {
			// Input::set_gyroscope(Vector3) hash from Godot 4.6 extension_api.json.
			g_set_gyro_bind = g_get_method_bind((GDExtensionConstStringNamePtr)sn_input, (GDExtensionConstStringNamePtr)sn_method, 3460891852LL);
		}
		if (sn_dtor) {
			sn_dtor(sn_input);
			sn_dtor(sn_method);
		}
	}
}

static void controller_motion_frame(void) {
	if (g_skip_for_automated_run || !g_input_singleton || !g_set_gyro_bind) {
		return;
	}
	@autoreleasepool {
		NSArray<GCController *> *controllers = [GCController controllers];
		for (GCController *controller in controllers) {
			GCMotion *motion = controller.motion;
			if (!motion) {
				continue;
			}
			if (@available(macOS 11.0, iOS 14.0, *)) {
				if (motion.sensorsRequireManualActivation && !motion.sensorsActive) {
					motion.sensorsActive = YES;
				}
			}
			GCRotationRate r = motion.rotationRate;
			GCAcceleration g = motion.gravity;
			// Player-space horizontal yaw: project rotationRate onto the world up vector (-gravity)
			// so turning the controller horizontally works whether held flat, tilted, or upright.
			double up_x = -g.x;
			double up_y = -g.y;
			double up_z = -g.z;
			double up_len = sqrt(up_x * up_x + up_y * up_y + up_z * up_z);
			double yaw_left = (up_len > 0.1)
				? (r.x * (up_x / up_len) + r.y * (up_y / up_len) + r.z * (up_z / up_len))
				: r.z;
			double pitch_up = r.x;
			double mag = sqrt(pitch_up * pitch_up + yaw_left * yaw_left);
			const double deadzone = 0.018;
			float gyro[3] = {0.0f, 0.0f, 0.0f};
			if (mag > deadzone) {
				double scale = (mag - deadzone) / mag;
				gyro[0] = (float)(pitch_up * scale);
				gyro[1] = (float)(yaw_left * scale);
				gyro[2] = 0.0f;
			}
			const void *args[1] = { gyro };
			g_ptrcall(g_set_gyro_bind, g_input_singleton, (const GDExtensionConstTypePtr *)args, NULL);
			g_had_motion_controller = true;
			return;
		}
		if (g_had_motion_controller) {
			float zero[3] = {0.0f, 0.0f, 0.0f};
			const void *args[1] = { zero };
			g_ptrcall(g_set_gyro_bind, g_input_singleton, (const GDExtensionConstTypePtr *)args, NULL);
			g_had_motion_controller = false;
		}
	}
}

static void controller_motion_shutdown(void) {
	g_input_singleton = NULL;
	g_set_gyro_bind = NULL;
}

static void on_initialize(void *p_userdata, GDExtensionInitializationLevel p_level) {
	(void)p_userdata;
	(void)p_level;
}

static void on_deinitialize(void *p_userdata, GDExtensionInitializationLevel p_level) {
	(void)p_userdata;
	(void)p_level;
}

__attribute__((visibility("default")))
GDExtensionBool controller_motion_library_init(
	GDExtensionInterfaceGetProcAddress p_get_proc_address,
	GDExtensionClassLibraryPtr p_library,
	GDExtensionInitialization *r_initialization
) {
	g_sn_new = (GDExtensionInterfaceStringNameNewWithLatin1Chars)(void *)p_get_proc_address("string_name_new_with_latin1_chars");
	g_get_dtor = (GDExtensionInterfaceVariantGetPtrDestructor)(void *)p_get_proc_address("variant_get_ptr_destructor");
	g_get_singleton = (GDExtensionInterfaceGlobalGetSingleton)(void *)p_get_proc_address("global_get_singleton");
	g_get_method_bind = (GDExtensionInterfaceClassdbGetMethodBind)(void *)p_get_proc_address("classdb_get_method_bind");
	g_ptrcall = (GDExtensionInterfaceObjectMethodBindPtrcall)(void *)p_get_proc_address("object_method_bind_ptrcall");
	g_reg_callbacks = (GDExtensionInterfaceRegisterMainLoopCallbacks)(void *)p_get_proc_address("register_main_loop_callbacks");

	r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
	r_initialization->userdata = NULL;
	r_initialization->initialize = on_initialize;
	r_initialization->deinitialize = on_deinitialize;

	if (g_reg_callbacks) {
		GDExtensionMainLoopCallbacks callbacks = {
			.startup_func = controller_motion_startup,
			.shutdown_func = controller_motion_shutdown,
			.frame_func = controller_motion_frame,
		};
		g_reg_callbacks(p_library, &callbacks);
	}
	return 1;
}
