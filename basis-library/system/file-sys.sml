(* os-filesys.sml
 *
 * COPYRIGHT (c) 1995 AT&T Bell Laboratories.
 *
 * The Posix implementation of the generic file system interface.
 *
 *)

structure OS_FileSys: OS_FILE_SYS =
   struct
      structure Prim = Primitive.OS.FileSys
	 
      structure P_FSys = Posix.FileSys

      val sysWordToWord = Word.fromLargeWord o SysWord.toLargeWord

      type dirstream = P_FSys.dirstream

      val openDir   = P_FSys.opendir
      val readDir   = P_FSys.readdir
      val rewindDir = P_FSys.rewinddir
      val closeDir  = P_FSys.closedir

      val chDir  = P_FSys.chdir
      val getDir = P_FSys.getcwd
      local
	 structure S = P_FSys.S
	 val mode777 = S.flags[S.irwxu, S.irwxg, S.irwxo]
      in
	 fun mkDir path = P_FSys.mkdir(path, mode777)
      end
      val rmDir  = P_FSys.rmdir
      val isDir  = P_FSys.ST.isDir o P_FSys.stat

      val isLink   = P_FSys.ST.isLink o P_FSys.lstat
      val readLink = P_FSys.readlink

      (* the maximum number of links allowed *)
      val maxLinks = 64

      structure P = OS_Path

      (* A UNIX specific implementation of fullPath *)
      fun fullPath p =
	 let
	    val oldCWD = getDir()
	    fun mkPath pathFromRoot =
	       P.toString{isAbs=true, vol="", arcs=List.rev pathFromRoot}
	    fun walkPath (n, pathFromRoot, arcs) =
	       if n = 0
		  then raise PosixError.SysErr ("too many links", NONE)
	       else
		  case arcs of
		     [] => mkPath pathFromRoot
		   | arc :: al =>
			if arc = "" orelse arc = "."
			   then walkPath (n, pathFromRoot, al)
			else if arc = ".."
				then
				   (case pathFromRoot of
				       [] => walkPath (n, [], al)
				     | _ :: r =>
					  (chDir ".."; walkPath (n, r, al)))
		        else
			   if isLink arc
			      then expandLink (n, pathFromRoot, arc, [])
			   else
			      case al of
				 [] => mkPath (arc :: pathFromRoot)
			       | _ =>
				    (chDir arc
				     ; walkPath (n, arc :: pathFromRoot, al))
	    and expandLink (n, pathFromRoot, link, rest) =
	       (
		case (P.fromString(readLink link))
		   of {isAbs=false, arcs, ...} =>
		      walkPath (n-1, pathFromRoot, List.@(arcs, rest))
		 | {isAbs=true, arcs, ...} =>
		      gotoRoot (n-1, List.@(arcs, rest))
	    (* end case *))
	    and gotoRoot (n, arcs) = (chDir "/"
				      ; walkPath (n, [], arcs))
	    fun computeFullPath arcs =
	       (gotoRoot(maxLinks, arcs) before chDir oldCWD)
	       handle ex => (chDir oldCWD; raise ex)
	 in
	    case (P.fromString p)
	       of {isAbs=false, arcs, ...} =>
		  let
		     val {arcs=arcs', ...} = P.fromString(oldCWD)
		  in
		     computeFullPath (List.@(arcs', arcs))
		  end
	     | {isAbs=true, arcs, ...} => computeFullPath arcs
	 (* end case *)
	 end

      fun realPath p =
	 if (P.isAbsolute p)
	    then fullPath p
	 else P.mkRelative {path = fullPath p, relativeTo = fullPath(getDir())}

      val fileSize = P_FSys.ST.size o P_FSys.stat
      val modTime  = P_FSys.ST.mtime o P_FSys.stat
      fun setTime (path, NONE) = P_FSys.utime(path, NONE)
	| setTime (path, SOME t) = P_FSys.utime(path, SOME{actime=t, modtime=t})
      val remove   = P_FSys.unlink
      val rename   = P_FSys.rename

      datatype access_mode = datatype Posix.FileSys.access_mode

      fun access (path, al) =
	 let
	    fun cvt A_READ = P_FSys.A_READ
	      | cvt A_WRITE = P_FSys.A_WRITE
	      | cvt A_EXEC = P_FSys.A_EXEC
	 in
	    P_FSys.access (path, List.map cvt al)
	 end

      (* modified by sweeks *)
      val tmpName = fn _ => raise Fail "tmpName unimplemented"

      datatype file_id = FID of {dev: SysWord.word, ino: SysWord.word}

      fun fileId fname = let
			    val st = P_FSys.stat fname
			 in
			    FID{
				dev = P_FSys.devToWord(P_FSys.ST.dev st),
				ino = P_FSys.inoToWord(P_FSys.ST.ino st)
				}
			 end

      fun hash (FID{dev, ino}) = sysWordToWord(SysWord.+(SysWord.<<(dev, 0w16), ino))

      fun compare (FID{dev=d1, ino=i1}, FID{dev=d2, ino=i2}) =
	 if (SysWord.<(d1, d2))
	    then General.LESS
	 else if (SysWord.>(d1, d2))
		 then General.GREATER
	      else if (SysWord.<(i1, i2))
		      then General.LESS
		   else if (SysWord.>(i1, i2))
			   then General.GREATER
			else General.EQUAL

   end

(*
 * $Log: os-filesys.sml, v $
 * Revision 1.3  1997/06/07 15:27:51  jhr
 *   SML'97 Basis Library changes (phase 3; Posix changes)
 *
 * Revision 1.2  1997/02/26  21:00:32  george
 *    Defined a new top level Option structure. All 'a option related
 *    functions have been moved out of General.
 *
 * Revision 1.1.1.1  1997/01/14  01:38:25  george
 *   Version 109.24
 *
 *)
