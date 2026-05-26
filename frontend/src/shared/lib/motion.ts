// Framer Motion shared params per PRD §3.2.
// Importing from one place keeps timings consistent across the app —
// updating a value here updates every motion in the codebase.
//
// Framer Motion 共享参数（PRD §3.2）；改一处影响全局。

import type { Transition, TargetAndTransition } from "framer-motion";

export interface MotionPreset {
  initial: TargetAndTransition;
  animate: TargetAndTransition;
  exit: TargetAndTransition;
  transition: Transition;
}

export const spring: Transition = { type: "spring", stiffness: 280, damping: 28 };
export const easeOut: Transition = { duration: 0.22, ease: [0.2, 0.8, 0.2, 1] };
export const easeFast: Transition = { duration: 0.12, ease: [0.2, 0.8, 0.2, 1] };

export const fadeIn: MotionPreset = {
  initial: { opacity: 0 },
  animate: { opacity: 1 },
  exit: { opacity: 0 },
  transition: easeOut,
};

export const slideUp: MotionPreset = {
  initial: { opacity: 0, y: 8 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: 4 },
  transition: easeOut,
};

export const slideDown: MotionPreset = {
  initial: { opacity: 0, y: -8 },
  animate: { opacity: 1, y: 0 },
  exit: { opacity: 0, y: -4 },
  transition: easeOut,
};

export const scaleIn: MotionPreset = {
  initial: { opacity: 0, scale: 0.96 },
  animate: { opacity: 1, scale: 1 },
  exit: { opacity: 0, scale: 0.98 },
  transition: easeOut,
};

export const slideRight: MotionPreset = {
  initial: { x: "100%" },
  animate: { x: 0 },
  exit: { x: "100%" },
  transition: { type: "spring", stiffness: 320, damping: 32 },
};

export const slideLeft: MotionPreset = {
  initial: { x: "-100%" },
  animate: { x: 0 },
  exit: { x: "-100%" },
  transition: { type: "spring", stiffness: 320, damping: 32 },
};

export const scrim: MotionPreset = {
  initial: { opacity: 0 },
  animate: { opacity: 1 },
  exit: { opacity: 0 },
  transition: { duration: 0.18 },
};
