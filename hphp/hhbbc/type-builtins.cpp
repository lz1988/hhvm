/*
   +----------------------------------------------------------------------+
   | HipHop for PHP                                                       |
   +----------------------------------------------------------------------+
   | Copyright (c) 2010-present Facebook, Inc. (http://www.facebook.com)  |
   +----------------------------------------------------------------------+
   | This source file is subject to version 3.01 of the PHP license,      |
   | that is bundled with this package in the file LICENSE, and is        |
   | available through the world-wide-web at the following url:           |
   | http://www.php.net/license/3_01.txt                                  |
   | If you did not receive a copy of the PHP license and are unable to   |
   | obtain it through the world-wide-web, please send a note to          |
   | license@php.net so we can mail you a copy immediately.               |
   +----------------------------------------------------------------------+
*/
#include "hphp/hhbbc/type-builtins.h"

#include "hphp/runtime/base/type-string.h"
#include "hphp/hhbbc/representation.h"

namespace HPHP { namespace HHBBC {

//////////////////////////////////////////////////////////////////////

const StaticString s_Vector("HH\\Vector");
const StaticString s_Map("HH\\Map");
const StaticString s_Set("HH\\Set");

const StaticString s_add("add");
const StaticString s_addall("addall");
const StaticString s_append("append");
const StaticString s_clear("clear");
const StaticString s_remove("remove");
const StaticString s_removeall("removeall");
const StaticString s_removekey("removekey");
const StaticString s_set("set");
const StaticString s_setall("setall");

//////////////////////////////////////////////////////////////////////

bool is_collection_method_returning_this(borrowed_ptr<const php::Class> cls,
                                         borrowed_ptr<const php::Func> func) {
  if (!cls) return false;

  if (cls->name->isame(s_Vector.get())) {
    return
      func->name->isame(s_add.get()) ||
      func->name->isame(s_addall.get()) ||
      func->name->isame(s_append.get()) ||
      func->name->isame(s_clear.get()) ||
      func->name->isame(s_removekey.get()) ||
      func->name->isame(s_set.get()) ||
      func->name->isame(s_setall.get());
  }

  if (cls->name->isame(s_Map.get())) {
    return
      func->name->isame(s_add.get()) ||
      func->name->isame(s_addall.get()) ||
      func->name->isame(s_clear.get()) ||
      func->name->isame(s_remove.get()) ||
      func->name->isame(s_set.get()) ||
      func->name->isame(s_setall.get());
  }

  if (cls->name->isame(s_Set.get())) {
    return
      func->name->isame(s_add.get()) ||
      func->name->isame(s_addall.get()) ||
      func->name->isame(s_clear.get()) ||
      func->name->isame(s_remove.get()) ||
      func->name->isame(s_removeall.get());
  }

  return false;
}

Type native_function_return_type(borrowed_ptr<const php::Func> f,
                                 bool include_coercion_failures) {
  assert(f->nativeInfo);

  // If the function returns by ref, we can't say much about it. It can be a ref
  // or null.
  if (f->attrs & AttrReference) {
    return union_of(TRef, TInitNull);
  }

  // Infer the type from the HNI declaration
  auto const hni = f->nativeInfo->returnType;
  auto t = hni ? from_DataType(*hni) : TInitCell;
  // Non-simple types (ones that are represented by pointers) can always
  // possibly be null.
  if (t.subtypeOfAny(TStr, TArr, TVec, TDict,
                     TKeyset, TObj, TRes)) {
    t = union_of(t, TInitNull);
  } else {
    // Otherwise it should be a simple type or possibly everything.
    assert(t == TInitCell || t.subtypeOfAny(TBool, TInt, TDbl, TNull));
  }

  if (include_coercion_failures) {
    // If parameter coercion fails, we can also get null or false depending on
    // the function.
    if (f->attrs & AttrParamCoerceModeNull) {
      t = union_of(t, TInitNull);
    }
    if (f->attrs & AttrParamCoerceModeFalse) {
      t = union_of(t, TFalse);
    }
  }

  return remove_uninit(t);
}

}}
