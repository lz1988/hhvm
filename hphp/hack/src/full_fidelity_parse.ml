(**
 * Copyright (c) 2016, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

 (**
  *
  * Usage: full_fidelity_parse [OPTIONS] [FILES]
  *
  * --full-fidelity-json
  * --full-fidelity-errors
  * --full-fidelity-errors-all
  * --full-fidelity-s-expression
  * --original-parser-errors
  * --original-parser-s-expression
  * --program-text
  * --pretty-print
  * --show-file-name
  * --codegen
  *
  * TODO: Parser for things other than scripts:
  *       types, expressions, statements, declarations, etc.
  *)

module SyntaxError = Full_fidelity_syntax_error
module SyntaxTree = Full_fidelity_syntax_tree
module SourceText = Full_fidelity_source_text

module FullFidelityParseArgs = struct

  type t =
  {
    full_fidelity_json : bool;
    full_fidelity_errors : bool;
    full_fidelity_errors_all : bool;
    full_fidelity_s_expr : bool;
    original_parser_errors : bool;
    original_parser_s_expr : bool;
    program_text : bool;
    pretty_print : bool;
    show_file_name : bool;
    codegen : bool;
    files : string list
  }

  let make
    full_fidelity_json
    full_fidelity_errors
    full_fidelity_errors_all
    full_fidelity_s_expr
    original_parser_errors
    original_parser_s_expr
    program_text
    pretty_print
    show_file_name
    codegen
    files = {
    full_fidelity_json;
    full_fidelity_errors;
    full_fidelity_errors_all;
    full_fidelity_s_expr;
    original_parser_errors;
    original_parser_s_expr;
    program_text;
    pretty_print;
    show_file_name;
    codegen;
    files }

  let parse_args () =
    let usage = Printf.sprintf "Usage: %s [OPTIONS] filename\n" Sys.argv.(0) in
    let full_fidelity_json = ref false in
    let set_full_fidelity_json () = full_fidelity_json := true in
    let full_fidelity_errors = ref false in
    let set_full_fidelity_errors () = full_fidelity_errors := true in
    let full_fidelity_errors_all = ref false in
    let set_full_fidelity_errors_all () =
      full_fidelity_errors_all := true in
    let full_fidelity_s_expr = ref false in
    let set_full_fidelity_s_expr () = full_fidelity_s_expr := true in
    let original_parser_errors = ref false in
    let set_original_parser_errors () = original_parser_errors := true in
    let original_parser_s_expr = ref false in
    let set_original_parser_s_expr () = original_parser_s_expr := true in
    let program_text = ref false in
    let set_program_text () = program_text := true in
    let pretty_print = ref false in
    let set_pretty_print () = pretty_print := true in
    let show_file_name = ref false in
    let set_show_file_name () = show_file_name := true in
    let codegen = ref false in
    let set_codegen () = codegen := true in
    let files = ref [] in
    let push_file file = files := file :: !files in
    let options =  [
      (* modes *)
      "--full-fidelity-json",
        Arg.Unit set_full_fidelity_json,
        "Displays the full-fidelity parse tree in JSON format.";
      "--full-fidelity-errors",
        Arg.Unit set_full_fidelity_errors,
        "Displays the full-fidelity parser errors, if any.
Some errors may be filtered out.";
      "--full-fidelity-errors-all",
        Arg.Unit set_full_fidelity_errors_all,
        "Displays the full-fidelity parser errors, if any.
No errors are filtered out.";
      "--full-fidelity-s-expression",
        Arg.Unit set_full_fidelity_s_expr,
        "Displays the full-fidelity parse tree in S-expression format.";
      "--original-parser-errors",
        Arg.Unit set_original_parser_errors,
        "Displays the original parse tree errors, if any.";
      "--original-parser-s-expression",
        Arg.Unit set_original_parser_s_expr,
        "Displays the original parse tree in S-expression format.";
      "--program-text",
        Arg.Unit set_program_text,
        "Displays the text of the given file.";
      "--pretty-print",
        Arg.Unit set_pretty_print,
        "Displays the text of the given file after pretty-printing.";
      "--show-file-name",
        Arg.Unit set_show_file_name,
        "Displays the file name.";
      "--codegen",
        Arg.Unit set_codegen,
        "Displays codegen."] in
    Arg.parse options push_file usage;
    make
      !full_fidelity_json
      !full_fidelity_errors
      !full_fidelity_errors_all
      !full_fidelity_s_expr
      !original_parser_errors
      !original_parser_s_expr
      !program_text
      !pretty_print
      !show_file_name
      !codegen
      (List.rev !files)
end

open FullFidelityParseArgs

let print_error error = error
  |> Errors.to_absolute
  |> Errors.to_string
  |> output_string stdout

let print_full_fidelity_error source_text error =
  let text = SyntaxError.to_positioned_string
    error (SourceText.offset_to_position source_text) in
  Printf.printf "%s\n" text

(* returns a tuple of functions, classes, typedefs and consts *)
let parse_file filename =
  let path = Relative_path.create Relative_path.Dummy filename in
  let options = ParserOptions.default in
  let { Parser_hack.ast; _} = Parser_hack.from_file options path in
  Ast_utils.get_defs ast

let type_file filename (funs, classes, typedefs, consts) =
  NamingGlobal.make_env ParserOptions.default ~funs ~classes ~typedefs ~consts;
  let path = Relative_path.create Relative_path.Dummy filename in
  let name_function (_, fun_) =
    Typing_check_service.type_fun TypecheckerOptions.default path fun_ in
  let named_funs = Core.List.filter_map funs name_function in
  let name_class (_, class_) =
    Typing_check_service.type_class TypecheckerOptions.default path class_ in
  let named_classes = Core.List.filter_map classes name_class in
  let named_typedefs = [] in (* TODO *)
  let named_consts = [] in (* TODO *)
  (named_funs, named_classes, named_typedefs, named_consts)

let compile_file (funs, classes, typedefs, consts) =
  let compiled_functions = Hhbc_from_nast.from_functions funs in
  let compiled_classes = Hhbc_from_nast.from_classes classes in
  Hhas_program.make compiled_functions compiled_classes
  (* TODO: typedefs, consts *)

let do_codegen filename =
  let parsed_file = parse_file filename in
  let named_file = type_file filename parsed_file in
  let hhas_prog = compile_file named_file in
  Hhbc_hhas.to_string hhas_prog

let handle_file args filename =
  (* Parse with the full fidelity parser *)
  let file = Relative_path.create Relative_path.Dummy filename in
  let source_text = SourceText.from_file file in
  let syntax_tree = SyntaxTree.make source_text in
  let editable = Full_fidelity_editable_syntax.from_tree syntax_tree in

  (* Parse with the original parser *)
  let (original_errors, original_parse, _) = Errors.do_
    begin
      fun () -> Parser_hack.from_file ParserOptions.default file
    end in

  if args.show_file_name then begin
    Printf.printf "%s\n" filename
  end;
  if args.program_text then begin
    let text = Full_fidelity_editable_syntax.text editable in
    Printf.printf "%s\n" text
  end;
  if args.codegen then begin
    let codegen = do_codegen filename in
    Printf.printf "%s\n" codegen
  end;
  if args.pretty_print then begin
    let pretty = Full_fidelity_pretty_printer.pretty_print editable in
    Printf.printf "%s\n" pretty
  end;
  if args.full_fidelity_errors then begin
    let errors = (SyntaxTree.errors syntax_tree) in
    List.iter (print_full_fidelity_error source_text) errors
  end;
  if args.full_fidelity_errors_all then begin
    let errors = (SyntaxTree.all_errors syntax_tree) in
    List.iter (print_full_fidelity_error source_text) errors
  end;
  if args.full_fidelity_s_expr then begin
    let str = Debug.dump_full_fidelity syntax_tree in
    Printf.printf "%s" str
  end;
  if args.original_parser_errors then begin
    Errors.iter_error_list print_error original_errors
  end;
  if args.original_parser_s_expr then begin
    let ast = Ast.AProgram original_parse.Parser_hack.ast in
    let str = Debug.dump_ast ast in
    Printf.printf "%s\n" str
  end;
  if args.full_fidelity_json then begin
    let json = Full_fidelity_syntax_tree.to_json syntax_tree in
    let str = Hh_json.json_to_string json in
    Printf.printf "%s\n" str
  end

let rec main args files =
  match files with
  | [] -> ()
  | file :: tail ->
    begin
      Unix.handle_unix_error (handle_file args) file;
      main args tail
    end

let () =
   let args = parse_args () in
   EventLogger.init EventLogger.Event_logger_fake 0.0;
   let _ = SharedMem.init GlobalConfig.default_sharedmem_config in
   main args args.files
