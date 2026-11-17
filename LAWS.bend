# Terrarium -- the laws. What the island promises about where its light
# comes from, whatever the GitHub profile it grows from.
#
# Bend's F32 is axiomatic, so the geometry and the colours are not claimed:
# these laws are about the discrete parts of the scene, the things you count.
import Base
import ./scene.bend as S

# LAW: every mushroom glows. For any garden, the scene holds exactly one
# mushroom light per mushroom that grows: none is dark, none is a ghost.
law every_mushroom_glows:
  for +i: Nat
  for +g: S.Garden
  {List.length(&2, S.Lt, S.Lights.scan(i, g)) == S.Mush.count(i, g) : Nat}

# LAW: asking for n fireflies gives exactly n firefly lights.
law fireflies_count:
  for +n: Nat
  for +seed: U32
  {List.length(&2, S.Lt, S.Lights.flies(n, seed)) == n : Nat}

# LAW: at night, one firefly per day of your current streak (up to 16).
law one_firefly_per_streak_day:
  for +streak: U32
  for +seed: U32
  {List.length(&2, S.Lt, S.Lights.flies(S.Lights.nflies(False{}, streak), seed))
    == U32.to_nat(S.T.umin(16, streak)) : Nat}

# LAW: by day there are no fireflies, whatever the streak.
law no_fireflies_by_day:
  for +streak: U32
  {S.Lights.nflies(True{}, streak) == 0n : Nat}
