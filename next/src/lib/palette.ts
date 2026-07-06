export const palette = {
  categorical: [
    "#2a78d6", // 1 blue
    "#1baf7a", // 2 aqua
    "#eda100", // 3 yellow
    "#008300", // 4 green
    "#4a3aa7", // 5 violet
    "#e34948", // 6 red
    "#e87ba4", // 7 magenta
    "#eb6834", // 8 orange
  ],
  sequentialBlue: {
    100: "#cde2fb",
    250: "#86b6ef",
    450: "#2a78d6",
    600: "#184f95",
  },
  status: {
    good: "#0ca30c",
    warning: "#fab219",
    serious: "#ec835a",
    critical: "#d03b3b",
  },
  ink: {
    primary: "#0b0b0b",
    secondary: "#52514e",
    muted: "#898781",
    grid: "#e1e0d9",
  },
} as const;
