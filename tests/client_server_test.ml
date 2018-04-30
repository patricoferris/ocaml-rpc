
(** This test verifies that the client and server functions generated by the
    IDL interoperate correctly *)

module Interface(R : Idl.RPC) = struct
  open R

  let int_p = Idl.Param.mk Rpc.Types.int
  let add = R.declare "add"
      ["Add two numbers"]
      (int_p @-> int_p @-> returning int_p Idl.DefaultError.err)

  let implementation = implement
      { Idl.Interface.name = "Calc"; namespace = Some "Calc"; description = ["interface"]; version = (1,0,0) }
end

let test_call_core () =
  let server =
    let module Server = Interface(Idl.GenServerExn ()) in
    Server.add (fun a b -> a + b);
    Idl.server Server.implementation
  in
  let module Client = Interface(Idl.GenClientExnRpc(struct let rpc = server end)) in
  Alcotest.(check int) "add" 4 (Client.add 1 3)

let test_call_lwt _switch () =
  let open Lwt.Infix in

  let server =
    let module Server = Interface(Rpc_lwt.GenServer ()) in
    Server.add (fun a b -> Rpc_lwt.M.return (a + b));
    Rpc_lwt.server Server.implementation
  in
  let rpc call = server call in
  let module Client = Interface(Rpc_lwt.GenClient()) in
  let t =
    Client.add rpc 1 3 |> Rpc_lwt.M.lwt >|= function
    | Ok n -> Alcotest.(check int) "add" 4 n
    | _ -> Alcotest.fail "RPC call failed"
  in
  t

let test_call_async () =
  let open Async in

  let server =
    let module Server = Interface(Rpc_async.GenServer ()) in
    Server.add (fun a b -> Rpc_async.M.return (a + b));
    Rpc_async.server Server.implementation
  in
  let rpc = server in
  let module Client = Interface(Rpc_async.GenClient()) in
  let run () =
    Client.add rpc 1 3 |> Rpc_async.M.deferred >>= function
    | Ok n -> Alcotest.(check int) "add" 4 n; return ()
    | _ -> Alcotest.fail "RPC call failed"
  in
  Thread_safe.block_on_async_exn run

let tests =
  [ "test_call_core", `Quick, test_call_core
  ; Alcotest_lwt.test_case "test_call_lwt" `Quick test_call_lwt
  ; "test_call_async", `Quick, test_call_async
  ]
