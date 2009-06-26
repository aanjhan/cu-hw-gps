public class TreeNode
{
    private int type;
    private String value;
    TreeNode left, right;
    
    public TreeNode(int type, String value)
    {
        this.type=type;
        this.value=value;
        this.left=null;
        this.right=null;
    }
    public TreeNode(int type, TreeNode left, TreeNode right)
    {
        this.type=type;
        this.value="";
        this.left=left;
        this.right=right;
    }

    public int GetType(){ return type; }
    public String GetValue(){ return value; }
    public TreeNode GetLeft(){ return left; }
    public TreeNode GetRight(){ return right; }

    public void SetValue(String value){ this.value=value; }
    public void SetLeft(TreeNode left){ this.left=left; }
    public void SetRight(TreeNode right){ this.right=right; }
};