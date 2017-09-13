module cf.spew.bindings.libuv.tree;

mixin template RB_HEAD(string name, type) {
	mixin(`struct ` ~ name ~ ` {` ~ q{
			/// root of tree
			type* rbh_root;
	} ~ `}`);
}

template RB_ENTRY(type) {
	struct RB_ENTRY {
		/// left element
		type* rbe_left;
		/// right element
		type* rbe_right;
		/// parent element
		type* rbe_parent;
		/// node color
		int rbe_color;
	}
}

