(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)
open! IStd
module F = Format
module L = Logging
module Debug = PyDebug
module Builtin = PyBuiltin
module SMap = PyCommon.SMap
module SSet = PyCommon.SSet
module IMap = PyCommon.IMap

module Const = struct
  (** This module is a small layer above [FFI.Constant]. It turns all "byte" strings into strings,
      and the tuples from array to list.

      TODO: Maybe merge it with FFI.Constant.t *)

  type t =
    | Int of int64
    | Bool of bool
    | Float of float
    | String of string
    | Tuple of t list
    | Code of FFI.Code.t
    | Null
  [@@deriving compare]

  let rec pp fmt = function
    | Int i ->
        Int64.pp fmt i
    | Bool b ->
        Bool.pp fmt b
    | Float f ->
        Float.pp fmt f
    | String s ->
        String.pp fmt s
    | Null ->
        F.pp_print_string fmt "None"
    | Tuple tuple ->
        F.fprintf fmt "(@[%a@])" (Pp.seq ~sep:", " pp) tuple
    | Code {FFI.Code.co_name; co_freevars; co_cellvars} ->
        let sz = Array.length co_freevars + Array.length co_cellvars in
        let maybe_closure = sz <> 0 in
        F.fprintf fmt "Code(%s, %b)" co_name maybe_closure


  let rec from_const c =
    match (c : FFI.Constant.t) with
    | PYCBool b ->
        Bool b
    | PYCInt i ->
        Int i
    | PYCFloat f ->
        Float f
    | PYCString s ->
        String s
    | PYCBytes b ->
        let s = Bytes.to_string b in
        String s
    | PYCNone ->
        Null
    | PYCTuple tuple ->
        let rev_values =
          Array.fold ~init:[]
            ~f:(fun consts c ->
              let c = from_const c in
              c :: consts )
            tuple
        in
        Tuple (List.rev rev_values)
    | PYCCode code ->
        Code code


  let as_name = function String s -> Some s | _ -> None

  let as_names = function
    | String s ->
        Ok [s]
    | Null ->
        Ok []
    | Tuple tuple ->
        let opt_lst = List.map ~f:as_name tuple in
        let opt_lst = Option.all opt_lst in
        Result.of_option ~error:() opt_lst
    | _ ->
        Error ()
end

module ConstMap = Caml.Map.Make (Const)

module Ident = struct
  (** An identifier is a sequence of strings, a qualified name. We only keep track of some shallow
      source: an identifier can be [Imported], a [Builtin], or a [Normal] identifier otherwise *)

  type kind = Builtin | Imported | Normal

  (* An identifier is never empty, hence the [root] field. Then we mostly add
     or remove qualifier at the end of the path, so [path] is a reversed list
     of the attribute access on [root] *)
  type t = {root: string; path: string list; kind: kind}

  let pp fmt {root; path} =
    if List.is_empty path then F.pp_print_string fmt root
    else F.fprintf fmt "%s.%a" root (Pp.seq ~sep:"." F.pp_print_string) (List.rev path)


  let mk ?(kind = Normal) root = {root; path= []; kind}

  let from_string ?(kind = Normal) ~on s =
    let l = String.split ~on s in
    match l with
    | [] ->
        L.die ExternalError "Ident.from_string with an empty string"
    | hd :: tl ->
        {root= hd; path= List.rev tl; kind}


  let extend {root; path; kind} attr = {root; path= attr :: path; kind}

  let append {root; path; kind} attrs = {root; path= List.rev_append attrs path; kind}
    [@@warning "-unused-value-declaration"]


  let pop {root; path; kind} = match path with [] -> None | _ :: path -> Some {root; path; kind}

  let length {path} = 1 + List.length path

  let root {root; kind} = {root; path= []; kind}
end

module SSA = struct
  type t = int

  let pp fmt i = F.fprintf fmt "n%d" i

  let next n = 1 + n
end

module BuiltinCaller = struct
  type format_function = Str | Repr | Ascii

  let show_format_function = function Str -> "str" | Repr -> "repr" | Ascii -> "ascii"

  let show_binary op =
    match (op : Builtin.binary_op) with
    | Add ->
        "Add"
    | And ->
        "And"
    | FloorDivide ->
        "FloorDivide"
    | LShift ->
        "LShift"
    | MatrixMultiply ->
        "MatrixMultiply"
    | Modulo ->
        "Modulo"
    | Multiply ->
        "Multiply"
    | Or ->
        "Or"
    | Power ->
        "Power"
    | RShift ->
        "RShift"
    | Subtract ->
        "Subtract"
    | TrueDivide ->
        "TrueDivide"
    | Xor ->
        "Xor"


  let show_unary op =
    match (op : Builtin.unary_op) with
    | Positive ->
        "Positive"
    | Negative ->
        "Negative"
    | Not ->
        "Not"
    | Invert ->
        "Invert"


  type t =
    | BuildClass  (** [LOAD_BUILD_CLASS] *)
    | Format
    | FormatFn of format_function
    | Inplace of Builtin.binary_op
    | Binary of Builtin.binary_op
    | Unary of Builtin.unary_op
    | Compare of Builtin.Compare.t
    | GetIter  (** [GET_ITER] *)
    | NextIter  (** [FOR_ITER] *)
    | HasNextIter  (** [FOR_ITER] *)
    | IterData  (** [FOR_ITER] *)

  let pp fmt = function
    | BuildClass ->
        F.pp_print_string fmt "$BuildClass"
    | Format ->
        F.pp_print_string fmt "$Format"
    | FormatFn fn ->
        F.fprintf fmt "$FormatFn.%s" (show_format_function fn)
    | Binary op ->
        let op = show_binary op in
        F.fprintf fmt "$Binary.%s" op
    | Inplace op ->
        let op = show_binary op in
        F.fprintf fmt "$Inplace.%s" op
    | Unary op ->
        let op = show_unary op in
        F.fprintf fmt "$Unary.%s" op
    | Compare op ->
        F.fprintf fmt "$Compare.%a" Builtin.Compare.pp op
    | GetIter ->
        F.pp_print_string fmt "$GetIter"
    | NextIter ->
        F.pp_print_string fmt "$NextIter"
    | HasNextIter ->
        F.pp_print_string fmt "$HasNextIter"
    | IterData ->
        F.pp_print_string fmt "$IterData"
end

module Exp = struct
  type collection = List | Set | Tuple | Slice | Map | String

  type import_name = {id: Ident.t; fromlist: string list}

  let pp_import_name fmt {id; fromlist} =
    F.fprintf fmt "$ImportName(%a,@ from_list=[@[%a@]])" Ident.pp id
      (Pp.seq ~sep:", " F.pp_print_string)
      fromlist


  (** An expression is an abstraction of the state of Python bytecode interpreter, waiting to be
      turned into Textual. During the translation from bytecode to expressions, we introduce SSA
      identifiers for "yet to be named" expressions.

      In this IR, name resolution is done so naming is (mostly, cf comment on [MAKE_FUNCTION]) not
      ambiguous. Also, we have reconstructed the CFG of the program, lost during Python compilation
      (TODO) *)
  type t =
    | Const of Const.t
    | Var of Ident.t  (** Non ambiguous name for variables, imports, functions, classes, ... *)
    | LocalVar of string
    | Temp of SSA.t
    | Subscript of {exp: t; index: t}  (** foo[bar] *)
    | Collection of {kind: collection; values: t list}
        (** Helper for [BUILD_LIST] and other builder opcodes *)
    | ConstMap of t ConstMap.t
    | Function of
        {qualname: Ident.t; code: FFI.Code.t; annotations: t ConstMap.t (* TODO: default values *)}
        (** Result of the [MAKE_FUNCTION] opcode *)
    | Class of t list
        (** Result of calling [LOAD_BUILD_CLASS] to create a class. Not much is processed of its
            content for now *)
    | GetAttr of (t * string) (* foo.bar *)
    | LoadMethod of (t * string)  (** [LOAD_METHOD] *)
    | ImportName of import_name  (** [IMPORT_NAME] *)
    | ImportFrom of {from: import_name; name: string}  (** [IMPORT_FROM] *)
    | LoadClosure of string  (** [LOAD_CLOSURE] *)
    | Not of t
    | BuiltinCaller of BuiltinCaller.t

  let rec pp fmt = function
    | Const c ->
        Const.pp fmt c
    | Var id ->
        Ident.pp fmt id
    | LocalVar s ->
        F.pp_print_string fmt s
    | Temp i ->
        SSA.pp fmt i
    | Subscript {exp; index} ->
        F.fprintf fmt "%a[@[%a@]]" pp exp pp index
    | Collection {kind; values} -> (
      match kind with
      | List ->
          F.fprintf fmt "[@[%a@]]" (Pp.seq ~sep:", " pp) values
      | Set ->
          F.fprintf fmt "{@[%a@]}" (Pp.seq ~sep:", " pp) values
      | Map ->
          F.fprintf fmt "{|@[%a@]|}" (Pp.seq ~sep:", " pp) values
      | Tuple ->
          F.fprintf fmt "(@[%a@])" (Pp.seq ~sep:", " pp) values
      | String ->
          F.fprintf fmt "$Concat(%a)" (Pp.seq ~sep:", " pp) values
      | Slice ->
          F.fprintf fmt "[@[%a@]]" (Pp.seq ~sep:":" pp) values )
    | ConstMap map ->
        F.fprintf fmt "{@[" ;
        ConstMap.iter (fun key exp -> F.fprintf fmt "%a: %a, " Const.pp key pp exp) map ;
        F.fprintf fmt "@]}"
    | Function {qualname; code} ->
        let {FFI.Code.co_name} = code in
        F.fprintf fmt "$FuncObj(%s, %a)" co_name Ident.pp qualname
    | Class cls ->
        F.fprintf fmt "$ClassObj(%a)" (Pp.seq ~sep:", " pp) cls
    | GetAttr (t, name) ->
        F.fprintf fmt "%a.%s" pp t name
    | LoadMethod (self, meth) ->
        F.fprintf fmt "$LoadMethod(%a, %s)" pp self meth
    | ImportName {id; fromlist} ->
        F.fprintf fmt "$ImportName(%a,@ from_list= [@[%a@]])" Ident.pp id
          (Pp.seq ~sep:", " F.pp_print_string)
          fromlist
    | ImportFrom {from; name} ->
        F.fprintf fmt "$ImportFrom(%a,@ name= %s)" pp_import_name from name
    | LoadClosure s ->
        F.fprintf fmt "$LoadClosure(%s)" s
    | Not exp ->
        F.fprintf fmt "$Not(%a)" pp exp
    | BuiltinCaller bc ->
        BuiltinCaller.pp fmt bc


  let as_short_string = function Const (String s) -> Some s | _ -> None
end

module Location = struct
  type t = int option

  let of_instruction {FFI.Instruction.starts_line} = starts_line

  let of_instructions = function instr :: _ -> of_instruction instr | [] -> None

  let of_code {FFI.Code.instructions} = of_instructions instructions
end

module Error = struct
  type kind =
    | EmptyStack of string
    | UnsupportedOpcode of string
    | MakeFunction of string * Exp.t
    | BuildConstKeyMapLength of int * int
    | BuildConstKeyMapKeys of Exp.t
    | LoadBuildClass of Exp.t list
    | LoadBuildClassName of Exp.t
    | ImportNameFromList of (string * Exp.t)
    | ImportNameLevel of (string * Exp.t)
    | ImportNameDepth of (Ident.t * int)
    | ImportFrom of (string * Exp.t)
    | CompareOp of int
    | UnpackSequence of int
    | FormatValueSpec of Exp.t
    | NextOffsetMissing
    | MissingBackEdge of int * int
    | InvalidBackEdge of (string * int * int)

  type t = L.error * Location.t * kind

  let pp_kind fmt = function
    | EmptyStack op ->
        F.fprintf fmt "Cannot %s, stack is empty" op
    | UnsupportedOpcode s ->
        F.fprintf fmt "Unsupported opcode: %s" s
    | MakeFunction (kind, exp) ->
        F.fprintf fmt "MAKE_FUNCTION: expected %s but got %a" kind Exp.pp exp
    | BuildConstKeyMapLength (m, n) ->
        F.fprintf fmt "BUILD_CONST_KEY_MAP: expected %d keys but got %d" m n
    | BuildConstKeyMapKeys exp ->
        F.fprintf fmt "BUILD_CONST_KEY_MAP: expect constant set of keys but got %a" Exp.pp exp
    | LoadBuildClass args ->
        F.fprintf fmt "LOAD_BUILD_CLASS: not enough arguments. Got %a" (Pp.seq ~sep:", " Exp.pp)
          args
    | LoadBuildClassName arg ->
        F.fprintf fmt "LOAD_BUILD_CLASS: expected a name, but got %a" Exp.pp arg
    | ImportNameFromList (name, args) ->
        F.fprintf fmt "IMPORT_NAME(%s): expected constant fromlist but got %a" name Exp.pp args
    | ImportNameLevel (name, arg) ->
        F.fprintf fmt "IMPORT_NAME(%s); expected int but got %a" name Exp.pp arg
    | ImportNameDepth (module_name, depth) ->
        F.fprintf fmt
          "IMPORT_NAME: module path %a is not deep enough for relative import with level %d"
          Ident.pp module_name depth
    | ImportFrom (name, from) ->
        F.fprintf fmt "IMPORT_FROM(%s): expected an `import` but got %a" name Exp.pp from
    | CompareOp n ->
        F.fprintf fmt "COMPARE_OP(%d): invalid operation" n
    | UnpackSequence n ->
        F.fprintf fmt "UNPACK_SEQUENCE: invalid count %d" n
    | FormatValueSpec exp ->
        F.fprintf fmt "FORMAT_VALUE: expected string literal, got %a" Exp.pp exp
    | NextOffsetMissing ->
        F.fprintf fmt "Jump to next instruction detected, but next instruction is missing"
    | MissingBackEdge (from, to_) ->
        F.fprintf fmt "Invalid absolute jump: missing target of back-edge from %d to %d" from to_
    | InvalidBackEdge (name, expect, actual) ->
        F.fprintf fmt "Invalid backedge to #%s with arity mismatch (expecting %d but got %d)" name
          expect actual
end

module Stmt = struct
  (** Statements are an extension of Textual's statements: we still keep some specific Python
      behavior around, like the difference between [CALL_FUNCTION] and [CALL_METHOD] *)
  type call_arg = {name: string option; value: Exp.t}

  let pp_call_arg fmt {name; value} =
    match name with
    | None ->
        Exp.pp fmt value
    | Some name ->
        F.fprintf fmt "%s= %a" name Exp.pp value


  let unnamed_call_arg value = {name= None; value}

  let unnamed_call_args args = List.map ~f:unnamed_call_arg args

  type t =
    | Assign of {lhs: Exp.t; rhs: Exp.t}
    | Call of {lhs: SSA.t; exp: Exp.t; args: call_arg list}
    | CallMethod of {lhs: SSA.t; call: Exp.t; args: Exp.t list}
    | ImportName of Exp.import_name
    | BuiltinCall of {lhs: SSA.t; call: BuiltinCaller.t; args: Exp.t list}
    | SetupAnnotations

  let pp fmt = function
    | Assign {lhs; rhs} ->
        F.fprintf fmt "%a <- %a" Exp.pp lhs Exp.pp rhs
    | Call {lhs; exp; args} ->
        F.fprintf fmt "%a <- %a(@[%a@])" SSA.pp lhs Exp.pp exp (Pp.seq ~sep:", " pp_call_arg) args
    | CallMethod {lhs; call; args} ->
        F.fprintf fmt "%a <- $CallMethod(%a, @[%a@])" SSA.pp lhs Exp.pp call
          (Pp.seq ~sep:", " Exp.pp) args
    | ImportName import_name ->
        Exp.pp_import_name fmt import_name
    | BuiltinCall {lhs; call; args} ->
        F.fprintf fmt "%a <- %a(@[%a@])" SSA.pp lhs BuiltinCaller.pp call (Pp.seq ~sep:", " Exp.pp)
          args
    | SetupAnnotations ->
        F.pp_print_string fmt "$SETUP_ANNOTATIONS"
end

module Offset = struct
  type t = int

  let pp fmt n = F.pp_print_int fmt n

  let of_code instructions =
    match instructions with FFI.Instruction.{offset} :: _ -> Some offset | _ -> None


  let get ~loc opt = Result.of_option ~error:(L.InternalError, loc, Error.NextOffsetMissing) opt
end

module Label = struct
  type name = string

  let pp_name fmt name = F.pp_print_string fmt name

  (** A label is a position in the bytecode where the control-flow can jump. Think "if/then/else",
      loops, ... Some Python opcode are quite involved in how the stack might be modified during
      jumps. For example, [FOR_ITER] might leave a value on the stack at all time, popping it only
      on exit.

      To account for such complex scenario, each label has a [prelude] to modify the stack and the
      state in non-trivial ways. To avoid a full-recursive type definition between [State] and
      [Label], we generalize [prelude] to be ['a -> 'a] and we'll instantiate it with [State.t]
      later on *)
  type 'a t =
    { name: name
    ; ssa_parameters: SSA.t list
    ; processed: bool
    ; backedge: bool
    ; prelude: ('a -> 'a) option }

  let pp fmt {name; ssa_parameters} =
    F.fprintf fmt "#%s" name ;
    if not (List.is_empty ssa_parameters) then
      F.fprintf fmt "(%a)" (Pp.seq ~sep:", " SSA.pp) ssa_parameters


  let mk ?(backedge = false) ?prelude name ssa_parameters =
    {name; ssa_parameters; processed= false; backedge; prelude}


  let is_processed {processed} = processed

  let process label = {label with processed= true}
end

module Jump = struct
  type 'a info = {label: 'a Label.t; offset: Offset.t; ssa_args: Exp.t list}

  let pp_info fmt {label; offset; ssa_args} =
    F.fprintf fmt "JumpInfo(%a, %a, %d)" Label.pp label Offset.pp offset (List.length ssa_args)


  type 'a t =
    | Absolute of 'a info
    | Label of 'a info
    | Return of Exp.t
    | TwoWay of {condition: Exp.t; next_info: 'a info; other_info: 'a info}

  let pp fmt = function
    | Absolute info ->
        F.fprintf fmt "Absolute(%a)" pp_info info
    | Label info ->
        F.fprintf fmt "Label(%a)" pp_info info
    | Return ret ->
        F.fprintf fmt "Return(%a)" Exp.pp ret
    | TwoWay {condition; next_info; other_info} ->
        F.fprintf fmt "TwoWay(%a, %a, %a)" Exp.pp condition pp_info next_info pp_info other_info
    [@@warning "-unused-value-declaration"]
end

module Terminator = struct
  type node_call = {label: Label.name; ssa_args: Exp.t list}

  let pp_node_call fmt {label; ssa_args} =
    Label.pp_name fmt label ;
    if not (List.is_empty ssa_args) then F.fprintf fmt "(@[%a@])" (Pp.seq ~sep:", " Exp.pp) ssa_args


  type t =
    | Return of Exp.t
    | Jump of node_call list  (** non empty list *)
    | If of {exp: Exp.t; then_: t; else_: t}

  let rec pp fmt = function
    | Return exp ->
        F.fprintf fmt "return %a" Exp.pp exp
    | Jump lst ->
        F.fprintf fmt "jmp %a" (Pp.seq ~sep:", " pp_node_call) lst
    | If {exp; then_; else_} ->
        F.fprintf fmt "if %a then @[%a@] else @[%a@]" Exp.pp exp pp then_ pp else_


  let of_jump jump_info =
    let node_info {Jump.label; ssa_args} =
      let {Label.name} = label in
      {label= name; ssa_args}
    in
    let jmp node = Jump [node_info node] in
    match jump_info with
    | `OneTarget info ->
        jmp info
    | `TwoTargets (exp, then_, else_) ->
        let then_ = jmp then_ in
        let else_ = jmp else_ in
        If {exp; then_; else_}
end

module CFG = struct
  type 'a t = {labels: 'a Label.t IMap.t; fresh_label: int}

  let empty = {labels= IMap.empty; fresh_label= 0}

  let fresh_label ({fresh_label} as cfg) =
    let fresh = sprintf "b%d" fresh_label in
    let cfg = {cfg with fresh_label= fresh_label + 1} in
    (fresh, cfg)


  let lookup_label {labels} offset = IMap.find_opt offset labels

  let process_label ({labels} as cfg) offset =
    match IMap.find_opt offset labels with
    | None ->
        cfg
    | Some label ->
        let label = Label.process label in
        let labels = IMap.add offset label labels in
        {cfg with labels}


  (** Helper to fetch label info if there's already one registered at the specified [offset], or
      create a fresh one. *)
  let get_label cfg ?prelude offset ~ssa_parameters =
    match lookup_label cfg offset with
    | Some label ->
        (label, cfg)
    | None ->
        let name, cfg = fresh_label cfg in
        let label = Label.mk name ?prelude ssa_parameters in
        (label, cfg)


  let register_label ({labels} as cfg) ~offset label =
    let labels = IMap.add offset label labels in
    {cfg with labels}
end

module Node = struct
  (** Linear block of code, without any jump. Starts with a label definition and ends with a
      terminator (jump, return, ...) *)
  type 'a t =
    { label: 'a Label.t
    ; label_loc: Location.t
    ; last_loc: Location.t
    ; stmts: (Location.t * Stmt.t) list
    ; last: Terminator.t }

  let pp fmt {label; stmts; last} =
    F.fprintf fmt "@[<hv2>%a:@\n" Label.pp label ;
    List.iter stmts ~f:(fun (_, stmt) -> F.fprintf fmt "@[<hv2>%a@]@\n" Stmt.pp stmt) ;
    F.fprintf fmt "%a@\n" Terminator.pp last ;
    F.fprintf fmt "@]@\n"
end

module State = struct
  (** Internal state of the Bytecode -> IR compiler *)
  type t =
    { module_name: Ident.t
    ; debug: bool
    ; loc: Location.t
    ; cfg: t CFG.t
    ; global_names: Ident.t SMap.t  (** Translation cache for global names *)
    ; stack: Exp.t list
    ; stmts: (Location.t * Stmt.t) list
    ; fresh_id: SSA.t
    ; classes: SSet.t
    ; functions: Ident.t SMap.t
    ; names: Ident.t SMap.t  (** Translation cache for local names *) }

  let known_global_names =
    let builtins =
      [ "print"
      ; "range"
      ; "open"
      ; "len"
      ; "type"
      ; "str"
      ; "int"
      ; "float"
      ; "bool"
      ; "object"
      ; "super"
      ; "hasattr"
      ; "__name__"
      ; "__file__" ]
    in
    List.fold builtins ~init:SMap.empty ~f:(fun names name ->
        SMap.add name (Ident.mk ~kind:Builtin name) names )


  let known_local_names =
    let locals = ["__name__"; "staticmethod"] in
    List.fold locals ~init:SMap.empty ~f:(fun names name ->
        SMap.add name (Ident.mk ~kind:Builtin name) names )


  let empty ~debug ~loc module_name =
    { module_name
    ; debug
    ; loc
    ; cfg= CFG.empty
    ; global_names= known_global_names
    ; stack= []
    ; stmts= []
    ; fresh_id= 0
    ; classes= SSet.empty
    ; functions= SMap.empty
    ; names= known_local_names }


  let debug {debug} = if debug then Debug.todo else Debug.p

  (** Each time a new object is discovered (they can be heavily nested), we need to clear the state
      of temporary data like the SSA counter, but keep other parts of it, like global and local
      names *)
  let enter {debug; global_names; names} ~loc module_name =
    let st = empty ~debug ~loc module_name in
    {st with global_names; names}


  let fresh_id ({fresh_id} as st) =
    let st = {st with fresh_id= SSA.next fresh_id} in
    (fresh_id, st)


  let is_toplevel {module_name} = Int.equal 1 (Ident.length module_name)

  let resolve_local_name names global_names name =
    match SMap.find_opt name names with
    | Some id ->
        Some id
    | None ->
        SMap.find_opt name global_names


  (** Python can look up names in the current namespace, or directly in the global namespace, which
      is why we keep them separated *)
  let resolve_name ~global ({names; global_names} as st) name =
    let global = global || is_toplevel st in
    debug st "resolve_name global= %b name= %s" global name ;
    let res =
      if global then SMap.find_opt name global_names else resolve_local_name names global_names name
    in
    match res with
    | Some id ->
        debug st " -> %a@\n" Ident.pp id ;
        id
    | None ->
        debug st " -> Not found@\n" ;
        let prefix = Ident.mk "$unknown" in
        Ident.extend prefix name


  let register_name ~global ({names; global_names} as st) name id =
    let global = global || is_toplevel st in
    debug st "register_name global= %b name= %s id= %a@\n" global name Ident.pp id ;
    if global then
      let global_names = SMap.add name id global_names in
      {st with global_names}
    else
      let names = SMap.add name id names in
      {st with names}


  let push ({stack} as st) exp = {st with stack= exp :: stack}

  let pop ({stack; loc} as st) =
    match stack with
    | [] ->
        Error (L.InternalError, loc, Error.EmptyStack "pop")
    | exp :: stack ->
        let st = {st with stack} in
        Ok (exp, st)


  let peek {stack; loc} =
    match stack with
    | [] ->
        Error (L.InternalError, loc, Error.EmptyStack "peek")
    | exp :: _ ->
        Ok exp


  let pop_n st n =
    let rec aux acc st n =
      let open IResult.Let_syntax in
      if n > 0 then
        let* hd, st = pop st in
        aux (hd :: acc) st (n - 1)
      else Ok (acc, st)
    in
    aux [] st n


  let push_stmt ({stmts; loc} as st) stmt = {st with stmts= (loc, stmt) :: stmts}

  let register_class ({classes} as st) cls = {st with classes= SSet.add cls classes}

  let register_function ({functions} as st) name fn = {st with functions= SMap.add name fn functions}

  let size {stack} = List.length stack

  (** When reaching a jump instruction, turn the stack into ssa variables *)
  let to_ssa ({stack} as st) =
    let st = {st with stack= []} in
    (stack, st)


  let mk_ssa_parameters st arity =
    let rec mk st acc n =
      if n > 0 then
        let i, st = fresh_id st in
        mk st (i :: acc) (n - 1)
      else (acc, st)
    in
    mk st [] arity


  let register_label ({cfg} as st) ~offset label =
    debug st "register_label %d %a@\n" offset Label.pp label ;
    let cfg = CFG.register_label cfg ~offset label in
    {st with cfg}


  let lookup_label {cfg} offset = CFG.lookup_label cfg offset

  let get_label ({cfg} as st) ?prelude offset ~ssa_parameters =
    let label, cfg = CFG.get_label cfg ?prelude offset ~ssa_parameters in
    let st = {st with cfg} in
    (label, st)


  let process_label ({cfg} as st) offset =
    let cfg = CFG.process_label cfg offset in
    {st with cfg}


  let fresh_label ({cfg} as st) =
    let fresh_label, cfg = CFG.fresh_label cfg in
    let st = {st with cfg} in
    (fresh_label, st)


  let starts_with_jump_target ({cfg} as st) = function
    | [] ->
        (None, st)
    | {FFI.Instruction.offset; is_jump_target} :: _ -> (
      match CFG.lookup_label cfg offset with
      | Some label ->
          let info = if Label.is_processed label then None else Some (offset, label) in
          (info, st)
      | None ->
          if is_jump_target then
            (* Probably the target of a back edge. Let's register a target with the current stack
               information. When we'll detect the jump to here, we'll make sure things are
               compatible *)
            let arity = size st in
            let ssa_parameters, st = mk_ssa_parameters st arity in
            let name, st = fresh_label st in
            let label = Label.mk ~backedge:true name ssa_parameters in
            let st = register_label st ~offset label in
            (Some (offset, label), st)
          else (None, st) )


  let enter_node st {Label.ssa_parameters; prelude} =
    let st = {st with stmts= []} in
    (* Install the prelude before processing the instructions *)
    let st = Option.value_map ~default:st ~f:(fun f -> f st) prelude in
    (* If we have ssa_parameters, we need to push them on the stack to restore its right shape.
       Doing a fold_right is important to keep the correct order. *)
    let st = List.fold_right ssa_parameters ~init:st ~f:(fun ssa st -> push st (Exp.Temp ssa)) in
    st


  let drain_stmts ({stmts} as st) =
    let st = {st with stmts= []} in
    (List.rev stmts, st)
end

let error kind {State.loc} err = Error (kind, loc, err)

let external_error st err = error L.ExternalError st err

let internal_error st err = error L.InternalError st err

let call_function_with_unnamed_args st exp args =
  let args = Stmt.unnamed_call_args args in
  let lhs, st = State.fresh_id st in
  let stmt = Stmt.Call {lhs; exp; args} in
  let st = State.push_stmt st stmt in
  (lhs, st)


let call_builtin_function st call args =
  let lhs, st = State.fresh_id st in
  let stmt = Stmt.BuiltinCall {lhs; call; args} in
  let st = State.push_stmt st stmt in
  (lhs, st)


(** Helper to compile the binary/unary/... ops into IR *)
let parse_op st call n =
  let open IResult.Let_syntax in
  let* args, st = State.pop_n st n in
  let lhs, st = call_builtin_function st call args in
  let st = State.push st (Exp.Temp lhs) in
  Ok (st, None)


(** Helper to compile the BUILD_ opcodes into IR *)
let build_collection st kind count =
  let open IResult.Let_syntax in
  let* values, st = State.pop_n st count in
  let exp = Exp.Collection {kind; values} in
  let st = State.push st exp in
  Ok (st, None)


let make_function st flags =
  let open IResult.Let_syntax in
  let* qualname, st = State.pop st in
  let* qualname =
    (* In the toplevel, [qualname] is the short name / string from the source.
       However in a nested context (e.g. in a class), [qualname] also prefixed
       by the value stored in the [__qualname__] attribute.
       We use this information along with our own [module_name] to generate a
       non ambiguous identifier *)
    match (qualname : Exp.t) with
    | Const (String s) ->
        let {State.module_name} = st in
        let root = Ident.root module_name in
        let lnames = String.split ~on:'.' s in
        Ok (Ident.append root lnames)
    | _ ->
        internal_error st (Error.MakeFunction ("a qualified named", qualname))
  in
  let* codeobj, st = State.pop st in
  let* code =
    match (codeobj : Exp.t) with
    | Const (Code c) ->
        Ok c
    | _ ->
        internal_error st (Error.MakeFunction ("a code object", codeobj))
  in
  let {FFI.Code.co_name= fn} = code in
  let* st =
    if flags land 0x08 <> 0 then
      (* TODO: closure *)
      let* _cells_for_closure, st = State.pop st in
      Ok st
    else Ok st
  in
  let* annotations, st =
    if flags land 0x04 <> 0 then
      let* annotations, st = State.pop st in
      let* annotations =
        match (annotations : Exp.t) with
        | ConstMap map ->
            Ok map
        | _ ->
            internal_error st (Error.MakeFunction ("some type annotations", annotations))
      in
      Ok (annotations, st)
    else Ok (ConstMap.empty, st)
  in
  let* st =
    if flags land 0x02 <> 0 then
      (* TODO: kw defaults *)
      let* _kw_defaults, st = State.pop st in
      Ok st
    else Ok st
  in
  (* TODO defaults *)
  let* _defaults, st =
    if flags land 0x01 <> 0 then
      let* defaults, st = State.pop st in
      Ok (Some defaults, st)
    else Ok (None, st)
  in
  let exp = Exp.Function {annotations; qualname; code} in
  let st = State.push st exp in
  let st = State.register_function st fn qualname in
  Ok (st, None)


let call_function st arg =
  let open IResult.Let_syntax in
  let* args, st = State.pop_n st arg in
  let* fun_exp, st = State.pop st in
  match (fun_exp : Exp.t) with
  | BuiltinCaller BuildClass ->
      (* Building a class looks like
          LOAD_BUILD_CLASS
          LOAD_CONST               CODE_OBJ
          LOAD_CONST               SHORT_NAME
          ... more arguments ...
          MAKE_FUNCTION            M
          LOAD_CONST               SHORT_NAME
          ... more arguments ...
          CALL_FUNCTION            N

         so we'll process it in a minimal way to extract the short name
         which is the second argument (the first being the code object)
      *)
      let sz = List.length args in
      let* () = if sz < 2 then external_error st (Error.LoadBuildClass args) else Ok () in
      let* short_name =
        match args with
        | _code :: short_name :: _ ->
            let {State.loc} = st in
            Result.of_option
              ~error:(L.InternalError, loc, Error.LoadBuildClassName short_name)
              (Exp.as_short_string short_name)
        | _ ->
            external_error st (Error.LoadBuildClass args)
      in
      let st = State.register_class st short_name in
      let exp = Exp.Class args in
      let st = State.push st exp in
      Ok (st, None)
  | BuiltinCaller call ->
      let id, st = call_builtin_function st call args in
      let st = State.push st (Exp.Temp id) in
      Ok (st, None)
  | _ ->
      let id, st = call_function_with_unnamed_args st fun_exp args in
      let st = State.push st (Exp.Temp id) in
      Ok (st, None)


let import_name st name =
  let open IResult.Let_syntax in
  let {State.module_name; loc} = st in
  let* fromlist, st = State.pop st in
  let* fromlist =
    let error = (L.ExternalError, loc, Error.ImportNameFromList (name, fromlist)) in
    match (fromlist : Exp.t) with
    | Const c ->
        Result.map_error ~f:(fun () -> error) (Const.as_names c)
    | _ ->
        Error error
  in
  let* level, st = State.pop st in
  let* level =
    match (level : Exp.t) with
    | Const (Int z) ->
        Ok (Int64.to_int_exn z)
    | _ ->
        external_error st (Error.ImportNameLevel (name, level))
  in
  let id = Ident.from_string ~kind:Imported ~on:'.' name in
  let* import_path =
    match level with
    | 0 ->
        (* Absolute path *)
        Ok id
    | _ -> (
        (* Relative path *)
        let rec pop_levels n id =
          match (n, id) with
          | 0, None ->
              Some `Root
          | 0, Some id ->
              Some (`Path id)
          | _, None ->
              None
          | _, Some id ->
              let next_id = Ident.pop id in
              pop_levels (n - 1) next_id
        in
        let prefix = pop_levels level (Some module_name) in
        match prefix with
        | Some `Root ->
            Ok id
        | Some (`Path prefix) ->
            if String.is_empty name then Ok prefix else Ok (Ident.extend prefix name)
        | None ->
            external_error st (Error.ImportNameDepth (module_name, level)) )
  in
  let import_name = {Exp.id= import_path; fromlist} in
  let exp = Exp.ImportName import_name in
  let st = State.push st exp in
  let stmt = Stmt.ImportName import_name in
  (* Keeping them as a statement so IR -> Textual can correctly generate the toplevel/side-effect call *)
  let st = State.push_stmt st stmt in
  Ok (st, None)


let import_from st name =
  let open IResult.Let_syntax in
  (* Does not pop the top of stack, which should be the result of an IMPORT_NAME *)
  let* from = State.peek st in
  let* ({Exp.fromlist} as from) =
    match (from : Exp.t) with
    | ImportName from ->
        Ok from
    | _ ->
        external_error st (Error.ImportFrom (name, from))
  in
  if not (List.mem ~equal:String.equal fromlist name) then
    L.user_warning "Import from / name mismatch: cannot find '%s'@\n" name ;
  let exp = Exp.ImportFrom {from; name} in
  let st = State.push st exp in
  Ok (st, None)


let target_of_import ~default exp =
  let target =
    match (exp : Exp.t) with
    | ImportName {id} ->
        Some id
    | ImportFrom {from= {id}; name} ->
        Some (Ident.extend id name)
    | _ ->
        None
  in
  Option.value ~default target


let unpack_sequence st count =
  let open IResult.Let_syntax in
  let* tos, st = State.pop st in
  let rec unpack st n =
    if n < 0 then st
    else
      let index = Exp.Const (Int (Int64.of_int n)) in
      let exp = Exp.Subscript {exp= tos; index} in
      let st = State.push st exp in
      unpack st (n - 1)
  in
  let* () = if count <= 0 then external_error st (Error.UnpackSequence count) else Ok () in
  let st = unpack st (count - 1) in
  Ok (st, None)


let format_value st flags =
  let open IResult.Let_syntax in
  let has_fmt_spec flags = Int.equal (flags land 0x04) 0x04 in
  let mk_conv flags =
    match flags land 0x03 with
    | 0x00 ->
        None
    | 0x01 ->
        Some BuiltinCaller.Str
    | 0x02 ->
        Some BuiltinCaller.Repr
    | 0x03 ->
        Some BuiltinCaller.Ascii
    | _ ->
        L.die InternalError "FORMAT_VALUE: unreachable"
  in
  let* fmt_spec, st =
    (* fmt_spec must be a string literal *)
    if has_fmt_spec flags then
      let* fmt_spec, st = State.pop st in
      match (fmt_spec : Exp.t) with
      | Const (String _) ->
          Ok (fmt_spec, st)
      | _ ->
          external_error st (Error.FormatValueSpec fmt_spec)
    else Ok (Exp.Const Null, st)
  in
  let* exp, st = State.pop st in
  let conv_fn = mk_conv flags in
  let exp, st =
    match conv_fn with
    | None ->
        (exp, st)
    | Some conv_fn ->
        let id, st = call_builtin_function st (FormatFn conv_fn) [exp] in
        (Exp.Temp id, st)
  in
  let id, st = call_builtin_function st Format [exp; fmt_spec] in
  let st = State.push st (Exp.Temp id) in
  Ok (st, None)


let pop_jump_if ~next_is st target next_offset_opt =
  let open IResult.Let_syntax in
  let {State.loc} = st in
  let* condition, st = State.pop st in
  (* Turn the stack into SSA parameters *)
  let arity = State.size st in
  let ssa_args, st = State.to_ssa st in
  let next_ssa, st = State.mk_ssa_parameters st arity in
  let other_ssa, st = State.mk_ssa_parameters st arity in
  let* next_offset = Offset.get ~loc next_offset_opt in
  let next_label, st = State.get_label st next_offset ~ssa_parameters:next_ssa in
  let other_label, st = State.get_label st target ~ssa_parameters:other_ssa in
  (* Compute the relevant pruning expressions *)
  let condition = if next_is then condition else Exp.Not condition in
  Ok
    ( st
    , Some
        (Jump.TwoWay
           { condition
           ; next_info= {label= next_label; offset= next_offset; ssa_args}
           ; other_info= {label= other_label; offset= target; ssa_args} } ) )


let jump_if_or_pop st ~jump_if target next_offset_opt =
  let open IResult.Let_syntax in
  let {State.loc} = st in
  (* We only peek the top of stack so the logic of [to_ssa] correctly captures it for
     the branch where "it stays". It will be restored as part of the stack restore logic when
     we process the "other" node. *)
  let* condition = State.peek st in
  let condition = if jump_if then Exp.Not condition else condition in
  let arity = State.size st in
  let ssa_args, st = State.to_ssa st in
  let next_ssa, st = State.mk_ssa_parameters st arity in
  let other_ssa, st = State.mk_ssa_parameters st arity in
  let* next_offset = Offset.get ~loc next_offset_opt in
  (* In the next branch, we make sure the top-of-stack is no longer in the ssa parameters
     so it is not restored, effectively dropped as per the opcode description. *)
  let next_label, st =
    let ssa_parameters = List.tl next_ssa |> Option.value ~default:[] in
    State.get_label st next_offset ~ssa_parameters
  in
  let next_ssa_args = List.tl ssa_args |> Option.value ~default:[] in
  let other_label, st = State.get_label st target ~ssa_parameters:other_ssa in
  Ok
    ( st
    , Some
        (Jump.TwoWay
           { condition
           ; next_info= {label= next_label; offset= next_offset; ssa_args= next_ssa_args}
           ; other_info= {label= other_label; offset= target; ssa_args} } ) )


(* TODO: maybe add pruning here ? *)
let for_iter st delta next_offset_opt =
  let open IResult.Let_syntax in
  let {State.loc} = st in
  let* iter, st = State.pop st in
  let id, st = call_builtin_function st NextIter [iter] in
  let has_item, st = call_builtin_function st HasNextIter [Exp.Temp id] in
  let condition = Exp.Temp has_item in
  let arity = State.size st in
  let ssa_args, st = State.to_ssa st in
  let next_ssa, st = State.mk_ssa_parameters st arity in
  let other_ssa, st = State.mk_ssa_parameters st arity in
  (* In the next branch, we know the iterator has an item available. Let's fetch it and
     push it on the stack. *)
  let next_prelude st =
    (* The iterator object stays on the stack while in the for loop, let's push it back *)
    let st = State.push st iter in
    (* The result of calling [__next__] is also pushed on the stack *)
    let next, st = call_builtin_function st IterData [Exp.Temp id] in
    State.push st (Exp.Temp next)
  in
  let* next_offset = Offset.get ~loc next_offset_opt in
  let next_label, st =
    State.get_label st next_offset ~ssa_parameters:next_ssa ~prelude:next_prelude
  in
  let other_offset = delta + next_offset in
  let other_label, st = State.get_label st other_offset ~ssa_parameters:other_ssa in
  Ok
    ( st
    , Some
        (Jump.TwoWay
           { condition
           ; next_info= {label= next_label; offset= next_offset; ssa_args}
           ; other_info= {label= other_label; offset= other_offset; ssa_args} } ) )


let parse_bytecode st {FFI.Code.co_consts; co_names; co_varnames; co_cellvars; co_freevars}
    {FFI.Instruction.opname; starts_line; arg; offset= instr_offset} next_offset_opt =
  let open IResult.Let_syntax in
  let st =
    if Option.is_some starts_line then (
      State.debug st "@\n" ;
      State.debug st ".line %d@\n" (Option.value_exn starts_line) ;
      {st with State.loc= starts_line} )
    else st
  in
  State.debug st "%s %d (0x%x)@\n" opname arg arg ;
  match opname with
  | "LOAD_CONST" ->
      let c = co_consts.(arg) in
      let c = Const.from_const c in
      let exp = Exp.Const c in
      let st = State.push st exp in
      Ok (st, None)
  | "LOAD_NAME" ->
      let name = co_names.(arg) in
      let target = State.resolve_name ~global:false st name in
      let exp = Exp.Var target in
      let st = State.push st exp in
      Ok (st, None)
  | "LOAD_GLOBAL" ->
      let name = co_names.(arg) in
      let target = State.resolve_name ~global:true st name in
      let exp = Exp.Var target in
      let st = State.push st exp in
      Ok (st, None)
  | "LOAD_FAST" ->
      let name = co_varnames.(arg) in
      let exp = Exp.LocalVar name in
      let st = State.push st exp in
      Ok (st, None)
  | "LOAD_ATTR" ->
      let name = co_names.(arg) in
      let* tos, st = State.pop st in
      let exp = Exp.GetAttr (tos, name) in
      let st = State.push st exp in
      Ok (st, None)
  | "STORE_NAME" ->
      let name = co_names.(arg) in
      let {State.module_name} = st in
      let target = Ident.extend module_name name in
      let lhs = Exp.Var target in
      let* rhs, st = State.pop st in
      let stmt = Stmt.Assign {lhs; rhs} in
      let target = target_of_import rhs ~default:target in
      let st = State.register_name ~global:false st name target in
      let st = State.push_stmt st stmt in
      Ok (st, None)
  | "STORE_GLOBAL" ->
      let name = co_names.(arg) in
      let {State.module_name} = st in
      let root = Ident.root module_name in
      let target = Ident.extend root name in
      let lhs = Exp.Var target in
      let* rhs, st = State.pop st in
      let stmt = Stmt.Assign {lhs; rhs} in
      let target = target_of_import rhs ~default:target in
      let st = State.register_name ~global:true st name target in
      let st = State.push_stmt st stmt in
      Ok (st, None)
  | "STORE_FAST" ->
      let name = co_varnames.(arg) in
      let lhs = Exp.LocalVar name in
      let* rhs, st = State.pop st in
      let stmt = Stmt.Assign {lhs; rhs} in
      let st = State.push_stmt st stmt in
      Ok (st, None)
  | "STORE_ATTR" ->
      let name = co_names.(arg) in
      let* root, st = State.pop st in
      let* rhs, st = State.pop st in
      let lhs = Exp.GetAttr (root, name) in
      let stmt = Stmt.Assign {lhs; rhs} in
      let st = State.push_stmt st stmt in
      Ok (st, None)
  | "STORE_SUBSCR" ->
      (* Implements TOS1[TOS] = TOS2.  *)
      let* index, st = State.pop st in
      let* exp, st = State.pop st in
      let* rhs, st = State.pop st in
      let lhs = Exp.Subscript {exp; index} in
      let stmt = Stmt.Assign {lhs; rhs} in
      let st = State.push_stmt st stmt in
      Ok (st, None)
  | "RETURN_VALUE" ->
      let* ret, st = State.pop st in
      Ok (st, Some (Jump.Return ret))
  | "CALL_FUNCTION" ->
      call_function st arg
  | "POP_TOP" -> (
      (* keep the popped values around in case their construction involves side effects *)
      let* rhs, st = State.pop st in
      match (rhs : Exp.t) with
      | ImportName _
      (* IMPORT_NAME are kept around for multiple 'from' statement and
         then popped. The translation to textual will use the statement
         version do deal with their side effect at the right location *)
      | Temp _ ->
          Ok (st, None)
      | _ ->
          let id, st = State.fresh_id st in
          let stmt = Stmt.Assign {lhs= Exp.Temp id; rhs} in
          let st = State.push_stmt st stmt in
          Ok (st, None) )
  | "BINARY_ADD" ->
      parse_op st (Binary Add) 2
  | "BINARY_SUBTRACT" ->
      parse_op st (Binary Subtract) 2
  | "BINARY_AND" ->
      parse_op st (Binary And) 2
  | "BINARY_FLOOR_DIVIDE" ->
      parse_op st (Binary FloorDivide) 2
  | "BINARY_LSHIFT" ->
      parse_op st (Binary LShift) 2
  | "BINARY_MATRIX_MULTIPLY" ->
      parse_op st (Binary MatrixMultiply) 2
  | "BINARY_MODULO" ->
      parse_op st (Binary Modulo) 2
  | "BINARY_MULTIPLY" ->
      parse_op st (Binary Multiply) 2
  | "BINARY_OR" ->
      parse_op st (Binary Or) 2
  | "BINARY_POWER" ->
      parse_op st (Binary Power) 2
  | "BINARY_RSHIFT" ->
      parse_op st (Binary RShift) 2
  | "BINARY_TRUE_DIVIDE" ->
      parse_op st (Binary TrueDivide) 2
  | "BINARY_XOR" ->
      parse_op st (Binary Xor) 2
  | "INPLACE_ADD" ->
      parse_op st (Inplace Add) 2
  | "INPLACE_SUBTRACT" ->
      parse_op st (Inplace Subtract) 2
  | "INPLACE_AND" ->
      parse_op st (Inplace And) 2
  | "INPLACE_FLOOR_DIVIDE" ->
      parse_op st (Inplace FloorDivide) 2
  | "INPLACE_LSHIFT" ->
      parse_op st (Inplace LShift) 2
  | "INPLACE_MATRIX_MULTIPLY" ->
      parse_op st (Inplace MatrixMultiply) 2
  | "INPLACE_MODULO" ->
      parse_op st (Inplace Modulo) 2
  | "INPLACE_MULTIPLY" ->
      parse_op st (Inplace Multiply) 2
  | "INPLACE_OR" ->
      parse_op st (Inplace Or) 2
  | "INPLACE_POWER" ->
      parse_op st (Inplace Power) 2
  | "INPLACE_RSHIFT" ->
      parse_op st (Inplace RShift) 2
  | "INPLACE_TRUE_DIVIDE" ->
      parse_op st (Inplace TrueDivide) 2
  | "INPLACE_XOR" ->
      parse_op st (Inplace Xor) 2
  | "UNARY_POSITIVE" ->
      parse_op st (Unary Positive) 1
  | "UNARY_NEGATIVE" ->
      parse_op st (Unary Negative) 1
  | "UNARY_NOT" ->
      parse_op st (Unary Not) 1
  | "UNARY_INVERT" ->
      parse_op st (Unary Invert) 1
  | "MAKE_FUNCTION" ->
      make_function st arg
  | "BUILD_CONST_KEY_MAP" ->
      let* keys, st = State.pop st in
      let* keys =
        match (keys : Exp.t) with
        | Const (Tuple keys) ->
            Ok keys
        | _ ->
            internal_error st (Error.BuildConstKeyMapKeys keys)
      in
      let nr_keys = List.length keys in
      let* tys, st = State.pop_n st arg in
      let* () =
        if Int.equal nr_keys arg then Ok ()
        else internal_error st (Error.BuildConstKeyMapLength (arg, nr_keys))
      in
      let map =
        List.fold2_exn ~init:ConstMap.empty ~f:(fun map key ty -> ConstMap.add key ty map) keys tys
      in
      let st = State.push st (Exp.ConstMap map) in
      Ok (st, None)
  | "BUILD_LIST" ->
      build_collection st List arg
  | "BUILD_SET" ->
      build_collection st Set arg
  | "BUILD_TUPLE" ->
      build_collection st Tuple arg
  | "BUILD_SLICE" ->
      build_collection st Slice arg
  | "BUILD_STRING" ->
      build_collection st String arg
  | "BUILD_MAP" ->
      build_collection st Map (2 * arg)
  | "BINARY_SUBSCR" ->
      let* index, st = State.pop st in
      let* exp, st = State.pop st in
      let exp = Exp.Subscript {exp; index} in
      let st = State.push st exp in
      Ok (st, None)
  | "LOAD_BUILD_CLASS" ->
      let st = State.push st (BuiltinCaller BuildClass) in
      Ok (st, None)
  | "LOAD_METHOD" ->
      let name = co_names.(arg) in
      let* tos, st = State.pop st in
      let exp = Exp.LoadMethod (tos, name) in
      let st = State.push st exp in
      Ok (st, None)
  | "CALL_METHOD" ->
      let* args, st = State.pop_n st arg in
      let* call, st = State.pop st in
      let lhs, st = State.fresh_id st in
      let stmt = Stmt.CallMethod {lhs; call; args} in
      let st = State.push_stmt st stmt in
      let st = State.push st (Exp.Temp lhs) in
      Ok (st, None)
  | "SETUP_ANNOTATIONS" ->
      let {State.module_name} = st in
      let annotations = Ident.extend module_name PyCommon.annotations in
      let st = State.register_name ~global:false st PyCommon.annotations annotations in
      let st = State.push_stmt st SetupAnnotations in
      Ok (st, None)
  | "IMPORT_NAME" ->
      let name = co_names.(arg) in
      import_name st name
  | "IMPORT_FROM" ->
      let name = co_names.(arg) in
      import_from st name
  | "COMPARE_OP" ->
      let* cmp_op =
        match List.nth Builtin.Compare.all arg with
        | Some op ->
            Ok op
        | None ->
            external_error st (Error.CompareOp arg)
      in
      let* rhs, st = State.pop st in
      let* lhs, st = State.pop st in
      let id, st = call_builtin_function st (Compare cmp_op) [lhs; rhs] in
      let st = State.push st (Exp.Temp id) in
      Ok (st, None)
  | "LOAD_CLOSURE" ->
      let cell =
        let sz = Array.length co_cellvars in
        if arg < sz then co_cellvars.(arg) else co_freevars.(arg - sz)
      in
      (* We currently do nothing. It will be up to the IR -> Textual step to deal with these *)
      let exp = Exp.LoadClosure cell in
      let st = State.push st exp in
      Ok (st, None)
  | "DUP_TOP" ->
      let* tos = State.peek st in
      let st = State.push st tos in
      Ok (st, None)
  | "UNPACK_SEQUENCE" ->
      unpack_sequence st arg
  | "FORMAT_VALUE" ->
      format_value st arg
  | "POP_JUMP_IF_TRUE" ->
      pop_jump_if ~next_is:false st arg next_offset_opt
  | "POP_JUMP_IF_FALSE" ->
      pop_jump_if ~next_is:true st arg next_offset_opt
  | "JUMP_FORWARD" ->
      let {State.loc} = st in
      (* This instruction gives us a relative delta w.r.t the next offset, so we turn it into an
         absolute offset right away *)
      let* next_offset = Offset.get ~loc next_offset_opt in
      let offset = next_offset + arg in
      let arity = State.size st in
      let ssa_args, st = State.to_ssa st in
      let ssa_parameters, st = State.mk_ssa_parameters st arity in
      let label, st = State.get_label st offset ~ssa_parameters in
      let jump = Jump.Absolute {ssa_args; label; offset} in
      Ok (st, Some jump)
  | "JUMP_ABSOLUTE" ->
      let arity = State.size st in
      let ssa_args, st = State.to_ssa st in
      let ssa_parameters, st = State.mk_ssa_parameters st arity in
      (* sanity check: we should already have allocated a label for this jump, if it is a backward
         edge. *)
      let* () =
        if arg < instr_offset then (
          match State.lookup_label st arg with
          | None ->
              external_error st (Error.MissingBackEdge (instr_offset, arg))
          | Some ({Label.name; backedge; ssa_parameters} as label) ->
              if not backedge then
                L.die InternalError "JUMP_ABSOLUTE: target %a at %d should be a back-edge" Label.pp
                  label arg ;
              let sz = List.length ssa_parameters in
              if sz <> arity then internal_error st (Error.InvalidBackEdge (name, arity, sz))
              else Ok () )
        else Ok ()
      in
      let label, st = State.get_label st arg ~ssa_parameters in
      let jump = Jump.Absolute {ssa_args; label; offset= arg} in
      Ok (st, Some jump)
  | "GET_ITER" ->
      let* tos, st = State.pop st in
      let id, st = call_builtin_function st GetIter [tos] in
      let exp = Exp.Temp id in
      let st = State.push st exp in
      Ok (st, None)
  | "FOR_ITER" ->
      for_iter st arg next_offset_opt
  | "JUMP_IF_TRUE_OR_POP" ->
      jump_if_or_pop ~jump_if:true st arg next_offset_opt
  | "JUMP_IF_FALSE_OR_POP" ->
      jump_if_or_pop ~jump_if:false st arg next_offset_opt
  | _ ->
      internal_error st (Error.UnsupportedOpcode opname)


let rec parse_bytecode_until_terminator ({State.loc} as st) code instructions =
  let open IResult.Let_syntax in
  let label_info, st = State.starts_with_jump_target st instructions in
  match label_info with
  | Some (_offset, label) ->
      (* If the analysis reached a known jump target, stop processing the node. *)
      let ssa_args, st = State.to_ssa st in
      let* offset = Offset.of_code instructions |> Offset.get ~loc in
      let info = {Jump.label; offset; ssa_args} in
      Ok (st, Some (Jump.Label info), instructions)
  | None -> (
    (* Otherwise, continue the analysis of the bytecode *)
    match instructions with
    | [] ->
        Ok (st, None, [])
    | instr :: remaining ->
        let next_offset_opt = Offset.of_code remaining in
        let* st, terminator = parse_bytecode st code instr next_offset_opt in
        if Option.is_some terminator then Ok (st, terminator, remaining)
        else parse_bytecode_until_terminator st code remaining )


let mk_node st label code instructions =
  let open IResult.Let_syntax in
  let label_loc = Location.of_instructions instructions in
  let st = State.enter_node st label in
  let* st, jump_op, instructions = parse_bytecode_until_terminator st code instructions in
  let stmts, st = State.drain_stmts st in
  let {State.loc= last_loc} = st in
  let jump_op =
    match jump_op with
    | None ->
        (* Unreachable: Python inserts [return None] at the end of any block
           without an explicit returns *)
        L.die ExternalError "mk_node: reached the EOF without a terminator"
    | Some jump_op ->
        jump_op
  in
  match (jump_op : _ Jump.t) with
  | Absolute ({label= next_label; offset} as info) ->
      let st = State.register_label st ~offset next_label in
      let last = Terminator.of_jump (`OneTarget info) in
      let node = {Node.label; last; stmts; last_loc; label_loc} in
      Ok (st, instructions, node)
  | Return ret ->
      let last = Terminator.Return ret in
      let node = {Node.label; last; stmts; last_loc; label_loc} in
      Ok (st, instructions, node)
  | Label ({offset} as info) ->
      (* Current invariant, might/will change with the introduction of * back-edges *)
      let opt = State.lookup_label st offset in
      if Option.is_none opt then L.die InternalError "stumbled upon unregistered label" ;
      (* A label was spotted after a non Terminator instruction. Insert a jump to this label to
         create a proper node, and resume the processing. *)
      let last = Terminator.of_jump (`OneTarget info) in
      let node = {Node.label; last; stmts; last_loc; label_loc} in
      Ok (st, instructions, node)
  | TwoWay {condition; next_info; other_info} ->
      let {Jump.label= next_label; offset= next_offset} = next_info in
      let {Jump.label= other_label; offset= other_offset} = other_info in
      (* The current node ended up with a two-way jump. Either continue to the "next"
         (fall-through) part of the code, or jump to the "other" section of the code. For this
         purpose, register a fresh label for the jump. *)
      let st = State.register_label st ~offset:next_offset next_label in
      let st = State.register_label st ~offset:other_offset other_label in
      (* Register the jump target *)
      let last = Terminator.of_jump (`TwoTargets (condition, next_info, other_info)) in
      let node = {Node.label; last; stmts; last_loc; label_loc} in
      Ok (st, instructions, node)


let rec mk_nodes st label code instructions =
  let open IResult.Let_syntax in
  let* st, instructions, node = mk_node st label code instructions in
  if List.is_empty instructions then Ok (st, [node])
  else
    let label, st =
      (* If the next instruction has a label, use it, otherwise pick a fresh one. *)
      let label_info, st = State.starts_with_jump_target st instructions in
      match label_info with
      | Some (offset, label) ->
          let st = State.process_label st offset in
          (label, st)
      | None ->
          let label_name, st = State.fresh_label st in
          (Label.mk label_name [], st)
    in
    let* st, nodes = mk_nodes st label code instructions in
    Ok (st, node :: nodes)


module Object = struct
  (** Everything in Python is an [Object]. A function is an [Object], a class is an [Object]. We
      will refine these into functions, classes and closures during the translation to Textual. *)

  type node = State.t Node.t

  type t =
    { name: Ident.t
    ; toplevel: node list
    ; objects: (Location.t * t) list (* TODO: maybe turn this into a map using classes/functions *)
    ; classes: SSet.t
    ; functions: Ident.t SMap.t }

  let rec pp fmt {name; toplevel; objects; classes; functions} =
    F.fprintf fmt "@[<hv2>object %a:@\n" Ident.pp name ;
    if not (List.is_empty toplevel) then (
      F.fprintf fmt "@[<hv2>code:@\n" ;
      List.iter toplevel ~f:(F.fprintf fmt "@[<hv2>%a@]@\n" Node.pp) ;
      F.fprintf fmt "@]@\n" ) ;
    if not (List.is_empty objects) then (
      F.fprintf fmt "@[<hv2>objects:@\n" ;
      List.iter objects ~f:(fun (_, obj) -> F.fprintf fmt "@[%a@]@\n" pp obj) ;
      F.fprintf fmt "@]@\n" ) ;
    if not (SSet.is_empty classes) then (
      F.fprintf fmt "@[<hv2>classes:@\n" ;
      SSet.iter (F.fprintf fmt "@[%a@]@\n" F.pp_print_string) classes ;
      F.fprintf fmt "@]@\n" ) ;
    if not (SMap.is_empty functions) then (
      F.fprintf fmt "@[<hv2>functions:@\n" ;
      SMap.iter (fun short long -> F.fprintf fmt "@[%s -> %a@]@\n" short Ident.pp long) functions ;
      F.fprintf fmt "@]" )
end

module Module = struct
  (** A module is just the "main" [Object] of a Python file, often called toplevel too *)
  type t = Object.t

  let pp fmt obj = F.fprintf fmt "module@\n%a@\n@\n" Object.pp obj
end

let rec mk_object st ({FFI.Code.instructions; co_consts} as code) =
  let open IResult.Let_syntax in
  let {State.module_name; loc} = st in
  let fresh_label, st = State.fresh_label st in
  let label = Label.mk fresh_label [] in
  let st = State.register_label st ~offset:0 label in
  let st = State.process_label st 0 in
  let* ({State.classes; functions} as st), nodes = mk_nodes st label code instructions in
  let* objects =
    Array.fold_result co_consts ~init:[] ~f:(fun objects constant ->
        match constant with
        | FFI.Constant.PYCCode code ->
            let {FFI.Code.co_name} = code in
            let module_name = Ident.extend module_name co_name in
            let loc = Location.of_code code in
            let st = State.enter st ~loc module_name in
            let* obj = mk_object st code in
            Ok (obj :: objects)
        | _ ->
            Ok objects )
  in
  let objects = List.rev objects in
  Ok (loc, {Object.name= module_name; toplevel= nodes; objects; classes; functions})


let mk ~debug ({FFI.Code.co_filename} as code) =
  let open IResult.Let_syntax in
  let file_path =
    let sz = String.length co_filename in
    if sz >= 2 && String.equal "./" (String.sub co_filename ~pos:0 ~len:2) then
      String.sub co_filename ~pos:2 ~len:(sz - 2)
    else co_filename
  in
  let file_path = Stdlib.Filename.remove_extension file_path in
  let module_name = Ident.from_string ~on:'/' file_path in
  let loc = Location.of_code code in
  let empty = State.empty ~debug ~loc module_name in
  let* _, obj = mk_object empty code in
  Ok obj
