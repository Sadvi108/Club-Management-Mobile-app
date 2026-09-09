import { useEffect, useState } from "react";
import { View, Text, Image, type ImageStyle, type StyleProp, type ViewStyle, type TextStyle } from "react-native";
import { Ionicons } from "@expo/vector-icons";
import { getApiOrigin } from "../api/config";

/**
 * Normalise a photo path coming back from Club.Api.
 *
 * Two shapes turn up. Most rows carry an absolute URL
 * (`https://www.maclubsystem.com/Files/DP/<guid>.png`), but the field is documented as
 * `Files/DP/...` and relative values do occur. A relative string is NOT a valid URI for
 * React Native's `<Image>`, which then silently renders nothing — on web the browser
 * resolves it against the page origin instead, so the same account can look fine in the
 * dev preview and blank in the APK. Both hosts serve `/Files/...`, so a relative path is
 * resolved against the current API origin.
 */
export function photoUrl(raw?: string | null): string | undefined {
  const s = (raw ?? "").trim();
  if (!s) return undefined;
  if (/^(https?:|data:|file:|content:)/i.test(s)) return s;
  return `${getApiOrigin().replace(/\/+$/, "")}/${s.replace(/^\/+/, "")}`;
}

type Props = {
  uri?: string | null;
  /** Initials to show when there is no usable image. Falls back to the icon if absent. */
  initials?: string;
  /** Icon shown when there are no initials either. */
  icon?: keyof typeof Ionicons.glyphMap;
  iconSize?: number;
  iconColor?: string;
  imageStyle: StyleProp<ImageStyle>;
  fallbackStyle?: StyleProp<ViewStyle>;
  initialsStyle?: StyleProp<TextStyle>;
  testID?: string;
};

/**
 * A remote avatar that degrades to initials or an icon.
 *
 * The screens used to render `uri ? <Image/> : <fallback/>`, which only covers an EMPTY
 * value. A URL that is present but does not resolve — a club whose logo was never uploaded
 * answers 404 with an HTML error page — left an empty circle with nothing in it. Load
 * failures now fall back too.
 */
export function Avatar({
  uri,
  initials,
  icon = "person",
  iconSize = 20,
  iconColor = "rgba(255,255,255,0.6)",
  imageStyle,
  fallbackStyle,
  initialsStyle,
  testID,
}: Props) {
  const src = photoUrl(uri);
  const [failed, setFailed] = useState(false);

  // A new URL deserves a fresh attempt — otherwise switching student/club keeps showing
  // the fallback from whichever image failed first.
  useEffect(() => setFailed(false), [src]);

  if (src && !failed) {
    return <Image source={{ uri: src }} style={imageStyle} onError={() => setFailed(true)} testID={testID} />;
  }
  return (
    <View style={[imageStyle, fallbackStyle]} testID={testID}>
      {initials ? (
        <Text style={initialsStyle}>{initials}</Text>
      ) : (
        <Ionicons name={icon} size={iconSize} color={iconColor} />
      )}
    </View>
  );
}
