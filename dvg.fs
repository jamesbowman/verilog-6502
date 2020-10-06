create dvg 8192 allot

: preload
    s" dump" r/o bin open-file abort" No such file" >r
    dvg 8192 r@ read-file throw 8192 <> throw
    r> close-file throw
;

s" out" w/o bin create-file drop constant out
create spot 2 allot
: >gd ( d. )
    swap
    spot w! spot 2 out write-file throw
    spot w! spot 2 out write-file throw
;

: dvg@
    2* dvg + w@ ;

variable x
variable y
variable scale
variable bright
variable sl

: fetch ( pc -- pc' insn )
    dup 1+ swap dvg@    ( pc insn )
    ;

: hi4 ( u -- u x )
    dup 12 rshift ;

: signed10 ( u -- x )
    dup $3ff and
    9 sl @ - rshift
    swap $400 and if negate then
    ;

: signed2 ( u -- x )
    dup $3 and 8 lshift
    9 sl @ - rshift
    swap $4 and if negate then
    ;

: s8
    dup 8 and 2* - ;

: gs ( x -- x ) \ global scale
    8 lshift
    scale @ s8 8 + lshift
    16 0 do 2/ loop
    ;

: plot
    cr ." xy " x @ . y @ . bright @ .
    ;

: draw ( x y )
    \ swap gs . gs .
    gs y +! gs x +!
    plot
    ;

: handle-VEC ( pc insn op )
    cr 14 spaces ." VEC "
    sl !
    signed10 >r
    fetch hi4 bright !
    signed10 
    r> draw
    ;

: handle-SVEC ( insn )
    cr 14 spaces ." SVEC "
    >r
    r@ 4 rshift $f and bright !
    r@ 11 rshift 1 and 
    r@ 3 rshift 1 and 2* +
    2 + sl !
    r@ signed2 r> 8 rshift signed2 draw
    ;

: run
    0
    begin
        fetch
        cr over 1- hex. dup hex.
        hi4
        case
        $a of
            $3ff and y !
            fetch hi4 scale ! $3ff and x !
            0 bright !
            plot
        endof
        $b of 2drop exit endof
        $c of $fff and endof
        $d of 2drop endof
        $f of handle-SVEC endof
        dup $a u< if
            handle-VEC
            0
        else
            abort" illegal opcode"
        then
        endcase
    again
;

preload
run
hex .s

cr x @ . y @ . scale @ .

$4567 $1234 >gd

out close-file throw
bye
