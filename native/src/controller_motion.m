// Native Apple GameController motion & touchpad bridge for Godot 4.5+.
// - Feeds gravity-aligned DualShock 4 / DualSense gyroscope rates into Input.set_gyroscope()
//   when a motion controller is connected (leaving handheld mobile IMU untouched otherwise).
// - Feeds DualShock 4 / DualSense touchpad state into Input.set_magnetometer(Vector3(x, y, state)),
//   where x, y are in [-1, 1] (+y = up) and state is 0 (idle), 1 (touching), or 2 (clicked).

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
static GDExtensionMethodBindPtr g_set_mag_bind = NULL;
static bool g_skip_for_automated_run = false;
static bool g_had_motion_controller = false;
static bool g_had_touchpad_controller = false;

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
		uint64_t sn_gyro[1] = {0};
		uint64_t sn_mag[1] = {0};
		g_sn_new((GDExtensionUninitializedStringNamePtr)sn_input, "Input", false);
		g_sn_new((GDExtensionUninitializedStringNamePtr)sn_gyro, "set_gyroscope", false);
		g_sn_new((GDExtensionUninitializedStringNamePtr)sn_mag, "set_magnetometer", false);
		g_input_singleton = g_get_singleton((GDExtensionConstStringNamePtr)sn_input);
		if (g_input_singleton) {
			// Input::set_gyroscope(Vector3) and Input::set_magnetometer(Vector3) share signature hash 3460891852.
			g_set_gyro_bind = g_get_method_bind((GDExtensionConstStringNamePtr)sn_input, (GDExtensionConstStringNamePtr)sn_gyro, 3460891852LL);
			g_set_mag_bind = g_get_method_bind((GDExtensionConstStringNamePtr)sn_input, (GDExtensionConstStringNamePtr)sn_mag, 3460891852LL);
		}
		if (sn_dtor) {
			sn_dtor(sn_input);
			sn_dtor(sn_gyro);
			sn_dtor(sn_mag);
		}
	}
}

static void controller_motion_frame(void) {
	if (g_skip_for_automated_run || !g_input_singleton) {
		return;
	}
	@autoreleasepool {
		NSArray<GCController *> *controllers = [GCController controllers];
		if (g_set_gyro_bind) {
			bool found_motion = false;
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
				found_motion = true;
				break;
			}
			if (!found_motion && g_had_motion_controller) {
				float zero[3] = {0.0f, 0.0f, 0.0f};
				const void *args[1] = { zero };
				g_ptrcall(g_set_gyro_bind, g_input_singleton, (const GDExtensionConstTypePtr *)args, NULL);
				g_had_motion_controller = false;
			}
		}

		if (g_set_mag_bind) {
			GCControllerButtonInput *tp_btn = nil;
			GCControllerDirectionPad *tp_pad = nil;
			for (GCController *controller in controllers) {
				GCExtendedGamepad *gp = controller.extendedGamepad;
				if (!gp) {
					continue;
				}
				if (@available(macOS 11.3, iOS 14.5, *)) {
					if ([gp isKindOfClass:[GCDualSenseGamepad class]]) {
						GCDualSenseGamepad *ds = (GCDualSenseGamepad *)gp;
						tp_btn = ds.touchpadButton;
						tp_pad = ds.touchpadPrimary;
						break;
					}
				}
				if (@available(macOS 11.0, iOS 14.0, *)) {
					if ([gp isKindOfClass:[GCDualShockGamepad class]]) {
						GCDualShockGamepad *ds4 = (GCDualShockGamepad *)gp;
						tp_btn = ds4.touchpadButton;
						tp_pad = ds4.touchpadPrimary;
						break;
					}
				}
			}
			if (tp_pad || tp_btn) {
				float x = tp_pad ? tp_pad.xAxis.value : 0.0f;
				float y = tp_pad ? tp_pad.yAxis.value : 0.0f;
				bool clicked = tp_btn ? tp_btn.isPressed : false;
				bool touching = (x != 0.0f || y != 0.0f);
				float pad[3] = { x, y, clicked ? 2.0f : (touching ? 1.0f : 0.0f) };
				const void *args[1] = { pad };
				g_ptrcall(g_set_mag_bind, g_input_singleton, (const GDExtensionConstTypePtr *)args, NULL);
				g_had_touchpad_controller = true;
			} else if (g_had_touchpad_controller) {
				float zero[3] = {0.0f, 0.0f, 0.0f};
				const void *args[1] = { zero };
				g_ptrcall(g_set_mag_bind, g_input_singleton, (const GDExtensionConstTypePtr *)args, NULL);
				g_had_touchpad_controller = false;
			}
		}
	}
}

static void controller_motion_shutdown(void) {
	g_input_singleton = NULL;
	g_set_gyro_bind = NULL;
	g_set_mag_bind = NULL;
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
