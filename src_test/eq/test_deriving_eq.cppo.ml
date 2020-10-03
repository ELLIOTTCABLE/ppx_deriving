open OUnit2

(* Mostly it is sufficient to test that the derived code compiles. *)

let printer = string_of_bool

type a1 = int        [@@ppx_deriving eq]
type a2 = int32      [@@ppx_deriving eq]
type a3 = int64      [@@ppx_deriving eq]
type a4 = nativeint  [@@ppx_deriving eq]
type a5 = float      [@@ppx_deriving eq]
type a6 = bool       [@@ppx_deriving eq]
type a7 = char       [@@ppx_deriving eq]
type a8 = string     [@@ppx_deriving eq]
type a9 = bytes      [@@ppx_deriving eq]
type r1 = int ref    [@@ppx_deriving eq]
type r2 = int Pervasives.ref [@@ocaml.warning "-3"][@@ppx_deriving eq]
type l  = int list   [@@ppx_deriving eq]
type a  = int array  [@@ppx_deriving eq]
type o  = int option [@@ppx_deriving eq]
type y  = int lazy_t [@@ppx_deriving eq]

let test_simple ctxt =
  assert_equal ~printer true  (equal_a1 1 1);
  assert_equal ~printer false (equal_a1 1 2)

let test_arr ctxt =
  assert_equal ~printer true (equal_a [||] [||]);
  assert_equal ~printer true (equal_a [|1|] [|1|]);
  assert_equal ~printer false (equal_a [||] [|1|]);
  assert_equal ~printer false (equal_a [|2|] [|1|])

let test_ref1 ctxt =
  assert_equal ~printer true (equal_r1 (ref 0) (ref 0))

let test_ref2 ctxt =
  assert_equal ~printer true (equal_r2 (ref 0) (ref 0))

type v = Foo | Bar of int * string | Baz of string [@@ppx_deriving eq]

#if OCAML_VERSION >= (4, 03, 0)
type rv = RFoo | RBar of { x: int; y: string; } [@@ppx_deriving eq]
#endif

type pv1 = [ `Foo | `Bar of int * string ] [@@ppx_deriving eq]
type pv2 = [ `Baz | pv1 ] [@@ppx_deriving eq]

type ty = int * string [@@ppx_deriving eq]

type re = {
  f1 : int;
  f2 : string;
} [@@ppx_deriving eq]

module M : sig
  type t = int [@@ppx_deriving eq]
end = struct
  type t = int [@@ppx_deriving eq]
end

type z = M.t [@@ppx_deriving eq]

type file = {
  name : string;
  perm : int     [@equal (<>)];
} [@@ppx_deriving eq]
let test_custom ctxt =
  assert_equal ~printer false (equal_file { name = ""; perm = 1 }
                                          { name = ""; perm = 1 });
  assert_equal ~printer true  (equal_file { name = ""; perm = 1 }
                                          { name = ""; perm = 2 })

type 'a pt = { v : 'a } [@@ppx_deriving eq]

let test_placeholder ctxt =
  assert_equal ~printer true ([%eq: _] 1 2)


type mrec_variant =
  | MrecFoo of string
  | MrecBar of int

and mrec_variant_list = mrec_variant list [@@ppx_deriving eq]

let test_mrec ctxt =
  assert_equal ~printer true  (equal_mrec_variant_list [MrecFoo "foo"; MrecBar 1]
                                                       [MrecFoo "foo"; MrecBar 1]);
  assert_equal ~printer false (equal_mrec_variant_list [MrecFoo "foo"; MrecBar 1]
                                                       [MrecFoo "bar"; MrecBar 1])

type e = Bool of be | Plus of e * e | IfE  of (be, e) if_e | Unit
and be = True | False | And of be * be | IfB of (be, be) if_e
and ('cond, 'a) if_e = 'cond * 'a * 'a
  [@@ppx_deriving eq]

let test_mut_rec ctxt =
  let e1 = IfE (And (False, True), Unit, Plus (Unit, Unit)) in
  let e2 = Plus (Unit, Bool False) in
  assert_equal ~printer true (equal_e e1 e1);
  assert_equal ~printer true (equal_e e2 e2);
  assert_equal ~printer false (equal_e e1 e2);
  assert_equal ~printer false (equal_e e2 e1)

type es =
  | ESBool of (bool [@nobuiltin])
  | ESString of (string [@nobuiltin])
and bool =
  | Bfoo of int * ((int -> int) [@equal fun _ _ -> true])
and string =
  | Sfoo of (String.t [@equal (=)]) * ((int -> int) [@equal fun _ _ -> true])
[@@ppx_deriving eq]

let test_std_shadowing ctxt =
  let e1 = ESBool (Bfoo (1, (+) 1)) in
  let e2 = ESString (Sfoo ("lalala", (+) 3)) in
  assert_equal ~printer false (equal_es e1 e2);
  assert_equal ~printer false (equal_es e2 e1);
  assert_equal ~printer true (equal_es e1 e1);
  assert_equal ~printer true (equal_es e2 e2)

type poly_app = float poly_abs
and 'a poly_abs = 'a
[@@ppx_deriving eq]

let test_poly_app ctxt =
  assert_equal ~printer true (equal_poly_app 1.0 1.0);
  assert_equal ~printer false (equal_poly_app 1.0 2.0)

module List = struct
  type 'a t = [`Cons of 'a | `Nil]
  [@@ppx_deriving eq]
end
type 'a std_clash = 'a List.t option
[@@ppx_deriving eq]

#if OCAML_VERSION >= (4, 03, 0)
let test_result ctxt =
  let eq = [%eq: (string, int) result] in
  assert_equal ~printer true (eq (Ok "ttt") (Ok "ttt"));
  assert_equal ~printer false (eq (Ok "123") (Error 123));
  assert_equal ~printer false (eq (Error 123) (Error 0))
#endif

let test_result_result ctxt =
  let open Result in
  let eq = [%eq: (string, int) result] in
  assert_equal ~printer true (eq (Ok "ttt") (Ok "ttt"));
  assert_equal ~printer false (eq (Ok "123") (Error 123));
  assert_equal ~printer false (eq (Error 123) (Error 0))

let suite = "Test deriving(eq)" >::: [
    "test_simple"        >:: test_simple;
    "test_array"         >:: test_arr;
    "test_ref1"          >:: test_ref1;
    "test_ref2"          >:: test_ref2;
    "test_custom"        >:: test_custom;
    "test_placeholder"   >:: test_placeholder;
    "test_mrec"          >:: test_mrec;
    "test_mut_rec"       >:: test_mut_rec;
    "test_std_shadowing" >:: test_std_shadowing;
    "test_poly_app"      >:: test_poly_app;
#if OCAML_VERSION >= (4, 03, 0)
    "test_result"        >:: test_result;
#endif
    "test_result_result" >:: test_result_result;
  ]

let _ = run_test_tt_main suite
