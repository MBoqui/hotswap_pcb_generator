include <parameters.scad>
include <param_processing.scad>

use <plate.scad>
use <switch.scad>
use <mcu.scad>
use <trrs.scad>
use <stabilizer.scad>
use <standoff.scad>

module case_shell(height, switch_layout, mcu_layout, trrs_layout, plate_layout, stab_layout) {
    // Additional wall thickness introduced by draft angle
    bottom_offset = (
        tan(case_wall_draft_angle) *
        (height-case_base_height) // Height of the drafted part of the wall
    );

    // Height of the chamfer with no draft angle
    base_chamfer_height = tan(case_chamfer_angle)*case_chamfer_width;

    // Offset of chamfer-draft intersection from base footprint (accounting for draft angle)
    chamfer_offset = min(
        case_wall_draft_angle > 0 ? ( // Special-case the no draft angle case, since that divides by zero
            base_chamfer_height *
            tan(case_wall_draft_angle) / // Converts to the added width of the drafted body at the undrafted chamfer edge
            (1-tan(case_wall_draft_angle)*tan(case_chamfer_angle)) // Solve for X to find the intersection of the draft and chamfer
        ) : 0, // No offset if the walls are vertical
        (height - case_base_height) / tan(case_chamfer_angle) // In cases where the chamfer doesn't intersect the draft, the chamfer stops at the base
    );

    // Total height to the chamfer-draft intersection
    chamfer_height = min(
        case_wall_draft_angle > 0 ? // More special casing to avoid dividing by zero
            chamfer_offset/tan(case_wall_draft_angle) :
            base_chamfer_height,
        height - case_base_height // Chamfer height can't exceed total case height
    );

    // Height of the drafted part of the wall
    draft_height = height - chamfer_height - case_base_height;

    // Use the outline as defined by the plate layout
    if (use_plate_layout_only) {
        if (case_wall_draft_angle == 0 && case_chamfer_width == 0) {
            // If there are no angles then the minkowski geometry becomes degenerate
            linear_extrude(height, convexity=10)
                plate_footprint(switch_layout, mcu_layout, trrs_layout, plate_layout, stab_layout);
        } else {
            minkowski() {
                // Just extrude the straight-sided base
                linear_extrude(case_base_height, convexity=10)
                    offset(-case_chamfer_width)
                    plate_footprint(switch_layout, mcu_layout, trrs_layout, plate_layout, stab_layout);

                // Side profile for both the chamfer and the draft angle
                union() {
                    translate([0,0,draft_height])
                        cylinder(chamfer_height, case_chamfer_width + chamfer_offset, 0); // Chamfer cone
                        cylinder(draft_height, bottom_offset + case_chamfer_width, case_chamfer_width + chamfer_offset); // Draft cone/cylinder
                }
            }
        }
    } else { // Just hull everything to get a basic shape (eliminates any concavity in the profile)
        eps = 0.001;
        hull() {
            // top plate surface
            translate([0,0,height-eps])
            linear_extrude(eps)
            offset(-case_chamfer_width)
                plate_footprint(switch_layout, mcu_layout, trrs_layout, plate_layout, stab_layout);

            // Chamfer-draft intersection
            translate([0,0,height-chamfer_height-eps])
            linear_extrude(eps)
            offset(chamfer_offset)
                plate_footprint(switch_layout, mcu_layout, trrs_layout, plate_layout, stab_layout);

            // Bottom section
            translate([0,0,-eps])
            linear_extrude(case_base_height+eps)
            offset(bottom_offset)
                plate_footprint(switch_layout, mcu_layout, trrs_layout, plate_layout, stab_layout);
        }
    }
}

module case(switch_layout, mcu_layout, trrs_layout, plate_layout, stab_layout, standoff_layout) {
    height = total_thickness - backplate_case_flange;
    intersection() {
        // Trim off any components that extend past the case (e.g. standoffs)
        translate([0,0,-height+plate_thickness/2])
            case_shell(height, switch_layout, mcu_layout, trrs_layout, plate_layout, stab_layout);
        difference() {
            union() {
                // Hollow out inside of case
                translate([0,0,-height+plate_thickness/2]) 
                difference() {
                    case_shell(height, switch_layout, mcu_layout, trrs_layout, plate_layout, stab_layout);
                    translate([0,0,-1])
                    linear_extrude(height-plate_thickness+1, convexity=10)
                        offset(-case_wall_thickness)
                        plate_footprint(switch_layout, mcu_layout, trrs_layout, plate_layout, stab_layout);
                }
                // Add undrilled standoffs
                layout_pattern(standoff_layout) {
                    plate_standoff($extra_data, true);
                }
            }
            // Add component cutouts
            layout_pattern(switch_layout) {
                switch_plate_cutout();
            }
            layout_pattern(mcu_layout) {
                mcu_case_cutout();
            }
            layout_pattern(trrs_layout) {
                trrs_case_cutout();
            }
            layout_pattern(stab_layout) {
                stabilizer_plate_cutout($extra_data);
            }

            // Drill all standoff holes
            layout_pattern(standoff_layout) {
                case_standoff_hole($extra_data);
                plate_standoff_hole($extra_data);
                translate([0,0,plate_thickness/2-pcb_plate_spacing-pcb_thickness-pcb_backplate_spacing-backplate_thickness/2-0.5])
                    backplate_standoff_hole($extra_data);
            }

            // Additional user-defined cutouts
            linear_extrude(plate_thickness+1, center=true)
            intersection() {
                // Make sure it doesn't cut into the case walls by intersecting with the inner plate profile
                offset(-case_wall_thickness)
                    plate_footprint(switch_layout, mcu_layout, trrs_layout, plate_layout, stab_layout);
                additional_plate_cutouts(); 
            }
        }
    }
}

case(
    switch_layout_final,
    mcu_layout_final,
    trrs_layout_final,
    plate_layout_final,
    stab_layout_final,
    standoff_layout_final
);
