# Terrarium -- the proofs. Counting laws are inductions on the list a
# light scan builds; the day law holds by computation.
import Base
import ./scene.bend as S
import ./LAWS.bend as Laws

# Putting a light adds one to the length exactly when the mushroom grows.
def Lemma.put_len(
  b: Bool, -l: S.Lt, -xs: List<&2, S.Lt>, -n: Nat,
  e: {List.length(&2, S.Lt, xs) == n : Nat}
) -> {List.length(&2, S.Lt, S.Lights.put(b, l, xs)) == S.Mush.add(b, n) : Nat}:
  match b:
    case True{}:
      %e : {1n+List.length(&2, S.Lt, xs) == 1n+_ : Nat}
      {==}
    case False{}:
      e

def Laws.every_mushroom_glows(i, g):
  match i:
    case 0n:
      {==}
    case 1n+k:
      Lemma.put_len(S.Mush.ok(g, S.Mush.cx(k), S.Mush.cz(k)), S.Mush.light(g, k),
        S.Lights.scan(k, g), S.Mush.count(k, g), Laws.every_mushroom_glows(k, g))

def Laws.fireflies_count(n, seed):
  match n:
    case 0n:
      {==}
    case 1n+k:
      %Laws.fireflies_count(k, seed) : {1n+List.length(&2, S.Lt, S.Lights.flies(k, seed)) == 1n+_ : Nat}
      {==}

def Laws.one_firefly_per_streak_day(streak, seed):
  Laws.fireflies_count(S.Lights.nflies(False{}, streak), seed)

def Laws.no_fireflies_by_day(streak):
  {==}
